const assert = require('node:assert/strict');
const {test} = require('node:test');
const cleanup = require('../.github/scripts/cleanup-jenkins-images.cjs');

const digest = id => `sha256:${id.toString(16).padStart(64, '0')}`;
const image = () => ({
  mediaType: 'application/vnd.oci.image.manifest.v1+json',
  config: {digest: digest(900)},
  layers: [{digest: digest(901)}],
});
const index = (...ids) => ({
  mediaType: 'application/vnd.oci.image.index.v1+json',
  manifests: ids.map(id => ({digest: digest(id)})),
});
const version = (id, tags = []) => ({
  id, name: digest(id), created_at: new Date(id * 1000).toISOString(),
  metadata: {container: {tags}},
});

function fixture(versions, manifests, options = {}) {
  const deleted = [];
  const fetched = [];
  let listings = 0;
  let summarized = false;
  const summary = {
    addHeading() { return this; },
    addRaw() { return this; },
    async write() { summarized = true; },
  };
  return {
    deleted, fetched,
    summarized: () => summarized,
    run: () => cleanup({
      context: {repo: {owner: 'Example', repo: 'Images'}, actor: 'test-actor'},
      core: {info() {}, setSecret() {}, summary},
      github: {
        async paginate(route, params) {
          assert.equal(params.per_page, 100);
          assert.equal(params.package_name, 'Images/jenkins');
          return ++listings === 2 && options.changedVersions ? options.changedVersions : versions;
        },
        async request(route, params) {
          if (options.deleteError) throw new Error('Delete forbidden');
          deleted.push(params.package_version_id);
        },
      },
      async fetch(url) {
        if (String(url).startsWith('https://ghcr.io/token?')) {
          return {
            ok: !options.tokenError, status: options.tokenError || 200,
            json: async () => ({token: 'test-token'}),
          };
        }
        const name = String(url).split('/').pop();
        fetched.push(name);
        const manifest = options.missingAfterDelete && deleted.length ? undefined : manifests[name];
        return {
          ok: Boolean(manifest), status: manifest ? 200 : 404,
          json: async () => manifest,
        };
      },
    }),
  };
}

test('keeps image and attestation children, but deletes obsolete roots and orphaned manifests', async () => {
  const versions = [
    ...[10, 20, 30, 40, 50, 60].map(id => version(id, [id === 60 ? 'latest' : `v${id}`])),
    ...[1, 2, 3, 4, 5, 6].map(id => version(id)),
  ];
  const manifests = Object.fromEntries([20, 30, 40, 50].map(id => [digest(id), image()]));
  manifests[digest(60)] = index(1, 2);
  manifests[digest(1)] = image();
  manifests[digest(2)] = {
    ...image(), annotations: {'vnd.docker.reference.type': 'attestation-manifest'},
  };
  const check = fixture(versions, manifests);
  await check.run();
  assert.deepEqual(check.deleted, [10, 3, 4, 5, 6]);
  assert.ok(check.fetched.includes(digest(1)));
  assert.ok(check.fetched.includes(digest(2)));
  assert.equal(check.summarized(), true);
});

test('protects older latest, nested indexes, shared children, and OCI subjects', async () => {
  const versions = [
    version(10, ['latest']), ...[20, 30, 40, 50, 60, 70].map(id => version(id, [`v${id}`])),
    ...[1, 2].map(id => version(id)), version(3, ['older-shared-image']),
  ];
  const manifests = Object.fromEntries([40, 50, 60, 70].map(id => [digest(id), image()]));
  manifests[digest(10)] = index(1);
  manifests[digest(30)] = index(1);
  manifests[digest(1)] = index(2);
  manifests[digest(2)] = {...image(), subject: {digest: digest(3)}};
  manifests[digest(3)] = image();
  const check = fixture(versions, manifests);
  await check.run();
  assert.deepEqual(check.deleted, [20]);
});

test('fails before deleting anything for missing or invalid retained dependencies and token errors', async () => {
  const cases = [
    {},
    {[digest(10)]: index(1)},
    {[digest(10)]: {...index(1), manifests: [{digest: 'invalid'}]}},
    {[digest(10)]: {mediaType: 'unsupported'}},
    {[digest(10)]: {...image(), config: {digest: 'invalid'}}},
    {[digest(10)]: index()},
  ];
  for (const manifests of cases) {
    const check = fixture([version(10, ['latest']), version(1)], manifests);
    await assert.rejects(check.run());
    assert.deepEqual(check.deleted, []);
    assert.equal(check.summarized(), false);
  }
  const check = fixture([version(10, ['latest'])], {}, {tokenError: 403});
  await assert.rejects(check.run(), /token request failed/);
  assert.deepEqual(check.deleted, []);
});

test('aborts when the package snapshot changes, and surfaces delete failures', async () => {
  const versions = [version(10, ['latest']), version(1)];
  const manifests = {[digest(10)]: image()};
  const changed = fixture(versions, manifests, {
    changedVersions: [version(10, ['latest']), version(1, ['new-tag'])],
  });
  await assert.rejects(changed.run(), /changed during cleanup/);
  assert.deepEqual(changed.deleted, []);
  const forbidden = fixture(versions, manifests, {deleteError: true});
  await assert.rejects(forbidden.run(), /Delete forbidden/);
  assert.equal(forbidden.summarized(), false);
});

test('does not report success if retained manifests become unreadable after deletion', async () => {
  const check = fixture(
    [version(10, ['latest']), version(1)],
    {[digest(10)]: image()},
    {missingAfterDelete: true},
  );
  await assert.rejects(check.run(), /Cannot read retained manifest/);
  assert.deepEqual(check.deleted, [1]);
  assert.equal(check.summarized(), false);
});
