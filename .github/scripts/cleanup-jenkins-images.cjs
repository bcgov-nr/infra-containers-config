const DIGEST = /^sha256:[a-f0-9]{64}$/;
const INDEX_TYPES = new Set([
  'application/vnd.oci.image.index.v1+json',
  'application/vnd.docker.distribution.manifest.list.v2+json',
]);
const MANIFEST_TYPES = new Set([
  'application/vnd.oci.image.manifest.v1+json',
  'application/vnd.docker.distribution.manifest.v2+json',
]);
const ACCEPT = [...INDEX_TYPES, ...MANIFEST_TYPES].join(', ');

module.exports = async function cleanup({
  github, context, core, fetch: fetchRegistry = globalThis.fetch,
}) {
  const packageName = `${context.repo.repo}/jenkins`;
  const imagePath = `${context.repo.owner}/${packageName}`.toLowerCase();
  const packageParams = {
    package_type: 'container',
    package_name: packageName,
    org: context.repo.owner,
  };
  const listVersions = () => github.paginate(
    'GET /orgs/{org}/packages/{package_type}/{package_name}/versions',
    {...packageParams, per_page: 100},
  );
  const versions = await listVersions();
  for (const version of versions) {
    if (!DIGEST.test(version.name) || !Number.isInteger(version.id)
        || !Number.isFinite(Date.parse(version.created_at))
        || !Array.isArray(version.metadata?.container?.tags)
        || !version.metadata.container.tags.every(tag => typeof tag === 'string')) {
      throw new Error(`Invalid GHCR package version metadata for ${version.id}`);
    }
  }

  const tagged = versions.filter(version => version.metadata.container.tags.length)
    .sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at) || b.id - a.id);
  // latest may point to an older image when newer tags are backfilled.
  const roots = new Set([
    ...tagged.slice(0, 5).map(version => version.name),
    ...tagged.filter(version => version.metadata.container.tags.includes('latest'))
      .map(version => version.name),
  ]);
  const protectedDigests = new Set();
  let registryToken;
  if (roots.size) {
    const tokenUrl = new URL('https://ghcr.io/token');
    tokenUrl.searchParams.set('service', 'ghcr.io');
    tokenUrl.searchParams.set('scope', `repository:${imagePath}:pull`);
    const credentials = Buffer.from(`${context.actor}:${process.env.GH_TOKEN}`).toString('base64');
    const response = await fetchRegistry(tokenUrl, {
      headers: {Authorization: `Basic ${credentials}`},
    });
    if (!response.ok) {
      throw new Error(`GHCR token request failed (HTTP ${response.status})`);
    }
    const token = await response.json();
    registryToken = token.token || token.access_token;
    if (typeof registryToken !== 'string' || !registryToken) {
      throw new Error('GHCR did not return a registry token');
    }
    core.setSecret(registryToken);
  }

  async function readManifest(digest) {
    if (!DIGEST.test(digest)) {
      throw new Error(`Invalid referenced manifest digest: ${digest}`);
    }
    const response = await fetchRegistry(
      `https://ghcr.io/v2/${imagePath}/manifests/${digest}`,
      {headers: {Authorization: `Bearer ${registryToken}`, Accept: ACCEPT}},
    );
    if (!response.ok) {
      throw new Error(`Cannot read retained manifest ${digest} (HTTP ${response.status})`);
    }
    const manifest = await response.json();
    if (INDEX_TYPES.has(manifest.mediaType)) {
      if (!Array.isArray(manifest.manifests) || !manifest.manifests.length) {
        throw new Error(`Invalid image index ${digest}`);
      }
    } else if (MANIFEST_TYPES.has(manifest.mediaType)) {
      if (!DIGEST.test(manifest.config?.digest) || !Array.isArray(manifest.layers)
          || !manifest.layers.every(layer => DIGEST.test(layer?.digest))) {
        throw new Error(`Invalid image manifest ${digest}`);
      }
    } else {
      throw new Error(`Unsupported manifest type for ${digest}: ${manifest.mediaType}`);
    }
    return manifest;
  }

  async function protect(digest) {
    if (protectedDigests.has(digest)) return;
    const manifest = await readManifest(digest);
    protectedDigests.add(digest);
    for (const child of manifest.manifests || []) {
      await protect(child?.digest);
    }
    if (manifest.subject) {
      await protect(manifest.subject.digest);
    }
  }
  for (const digest of roots) {
    await protect(digest);
  }

  // Fail before any deletion if tags or versions changed while resolving references.
  const snapshot = items => JSON.stringify(items.map(version => [
    version.id, version.name, [...version.metadata.container.tags].sort(),
  ]).sort((a, b) => a[0] - b[0]));
  if (snapshot(versions) !== snapshot(await listVersions())) {
    throw new Error('GHCR package versions changed during cleanup planning; rerun cleanup');
  }

  const deletions = versions.filter(version => !protectedDigests.has(version.name));
  // Remove obsolete tagged indexes before their unreferenced children.
  deletions.sort((a, b) => b.metadata.container.tags.length - a.metadata.container.tags.length);
  core.info(`Keeping ${roots.size} tagged roots and ${protectedDigests.size} referenced manifests`);
  for (const version of deletions) {
    core.info(`Deleting ${version.name} (tags: ${version.metadata.container.tags.join(', ') || 'none'})`);
    await github.request(
      'DELETE /orgs/{org}/packages/{package_type}/{package_name}/versions/{package_version_id}',
      {...packageParams, package_version_id: version.id},
    );
  }

  // Verify retained manifests remain readable after package-version deletion.
  for (const digest of protectedDigests) {
    await readManifest(digest);
  }
  await core.summary.addHeading('GHCR cleanup')
    .addRaw(`Kept the five newest tagged versions, latest, and their manifest dependencies. ` +
      `Protected ${protectedDigests.size} manifests; deleted ${deletions.length} package versions.\n`)
    .write();
};
