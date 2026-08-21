// FanCAD Essentials
//
// These commands exist to prove the plugin API is complete enough to write real
// drafting tools with. Each one is deliberately written the way a third party
// would have to write it: only through `fancad.*`, with no privileged access.

const { commands, document: doc, selection, window: win, geometry } = fancad;

function activate() {
  commands.register('essentials.grid', drawGrid);
  commands.register('essentials.centerMark', centerMarks);
  commands.register('essentials.boundingBox', boundingBox);
  commands.register('essentials.report', report);
  commands.register('essentials.dividePolyline', dividePolyline);
}

async function drawGrid(args) {
  const origin = geometry.point(args.origin);
  const spacing = Number(args.spacing);
  const columns = Math.max(1, Math.trunc(args.columns ?? 10));
  const rows = Math.max(1, Math.trunc(args.rows ?? 10));

  if (!(spacing > 0)) {
    throw new Error('spacing must be greater than zero');
  }

  const props = args.layer ? { layer: args.layer } : {};
  const width = spacing * columns;
  const height = spacing * rows;
  const edit = doc.beginEdit(`Grid ${columns}x${rows}`);

  for (let column = 0; column <= columns; column++) {
    const x = origin[0] + column * spacing;
    edit.line([x, origin[1]], [x, origin[1] + height], props);
  }
  for (let row = 0; row <= rows; row++) {
    const y = origin[1] + row * spacing;
    edit.line([origin[0], y], [origin[0] + width, y], props);
  }

  const result = await edit.commit();
  return {
    message: `Drew a ${columns} x ${rows} grid at ${spacing} units.`,
    created: result.created.length,
  };
}

async function centerMarks(args) {
  const oversize = Number(args.oversize ?? 1.25);
  const targets = await resolveTargets(args.ids, ['circle', 'arc']);
  if (targets.length === 0) {
    return { message: 'No circles or arcs to mark.' };
  }

  const edit = doc.beginEdit('Center marks');
  for (const id of targets) {
    const entity = await doc.entity(id);
    const [cx, cy] = entity.center;
    const reach = entity.radius * oversize;
    const props = { layer: entity.layer };
    edit.line([cx - reach, cy], [cx + reach, cy], props);
    edit.line([cx, cy - reach], [cx, cy + reach], props);
  }

  const result = await edit.commit();
  return {
    message: `Marked ${targets.length} ${plural(targets.length, 'centre')}.`,
    created: result.created.length,
  };
}

async function boundingBox(args) {
  const margin = Number(args.margin ?? 0);
  const ids = await resolveTargets(args.ids);
  if (ids.length === 0) {
    return { message: 'Nothing to enclose.' };
  }

  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const id of ids) {
    const [x0, y0, x1, y1] = (await doc.entity(id)).bounds;
    minX = Math.min(minX, x0);
    minY = Math.min(minY, y0);
    maxX = Math.max(maxX, x1);
    maxY = Math.max(maxY, y1);
  }
  minX -= margin;
  minY -= margin;
  maxX += margin;
  maxY += margin;

  const result = await doc
    .beginEdit('Bounding box')
    .polyline(
      [
        [minX, minY],
        [maxX, minY],
        [maxX, maxY],
        [minX, maxY],
      ],
      { closed: true },
    )
    .commit();

  return {
    message: `Enclosed ${ids.length} ${plural(ids.length, 'entity', 'entities')} in ${fixed(maxX - minX)} x ${fixed(maxY - minY)}.`,
    created: result.created.length,
    bounds: [minX, minY, maxX, maxY],
  };
}

async function report() {
  const summary = await doc.summary();
  const { layers } = await doc.layers();
  const lines = [];

  lines.push(`${summary.entityCount} entities on ${layers.length} layers.`);

  const kinds = Object.entries(summary.byKind).sort((a, b) => b[1] - a[1]);
  if (kinds.length > 0) {
    lines.push(kinds.map(([kind, count]) => `${kind} x${count}`).join(', '));
  }

  const perLayer = [];
  for (const layer of layers) {
    const { entities } = await doc.query({ layer: layer.name, limit: 100000 });
    if (entities.length === 0) continue;
    const flags = [
      layer.visible ? null : 'hidden',
      layer.locked ? 'locked' : null,
      layer.frozen ? 'frozen' : null,
    ].filter(Boolean);
    perLayer.push(
      `${layer.name}: ${entities.length}${flags.length ? ` (${flags.join(', ')})` : ''}`,
    );
  }
  if (perLayer.length > 0) lines.push(perLayer.join(' | '));

  const { entities: lineEntities } = await doc.query({
    kinds: ['line'],
    limit: 100000,
  });
  let totalLength = 0;
  for (const line of lineEntities) {
    const detail = await doc.entity(line.id);
    totalLength += geometry.distance(detail.start, detail.end);
  }
  if (lineEntities.length > 0) {
    lines.push(`Total line length ${fixed(totalLength)}.`);
  }

  if (summary.extents) {
    const [x0, y0, x1, y1] = summary.extents;
    lines.push(
      `Extents ${fixed(x0)}, ${fixed(y0)} to ${fixed(x1)}, ${fixed(y1)}.`,
    );
  }

  const message = lines.join('\n');
  await win.showMessage(message);
  return { message, entityCount: summary.entityCount };
}

async function dividePolyline(args) {
  const segments = Math.trunc(args.segments);
  if (segments < 2) throw new Error('segments must be at least 2');

  const entity = await doc.entity(idOf(args.target));
  const vertices = verticesOf(entity);
  if (vertices.length < 2) {
    throw new Error(`${entity.kind} cannot be divided`);
  }

  // Walk the polyline by arc length so the marks land at equal spacing rather
  // than at equal vertex counts.
  const spans = [];
  let total = 0;
  for (let i = 1; i < vertices.length; i++) {
    const length = geometry.distance(vertices[i - 1], vertices[i]);
    spans.push({ from: vertices[i - 1], to: vertices[i], length });
    total += length;
  }
  if (total === 0) throw new Error('the entity has zero length');

  const step = total / segments;
  const edit = doc.beginEdit(`Divide into ${segments}`);
  const props = { layer: entity.layer };

  let span = 0;
  let consumed = 0;
  for (let mark = 1; mark < segments; mark++) {
    const target = step * mark;
    while (span < spans.length - 1 && consumed + spans[span].length < target) {
      consumed += spans[span].length;
      span++;
    }
    const along = spans[span];
    const ratio = along.length === 0 ? 0 : (target - consumed) / along.length;
    edit.point(
      [
        along.from[0] + (along.to[0] - along.from[0]) * ratio,
        along.from[1] + (along.to[1] - along.from[1]) * ratio,
      ],
      props,
    );
  }

  const result = await edit.commit();
  return {
    message: `Placed ${result.created.length} points every ${fixed(step)} units.`,
    created: result.created.length,
    segmentLength: step,
  };
}

// --- helpers ---------------------------------------------------------------

/// Selection first, then the whole drawing. Matches how the built-in editing
/// commands behave, so these do not feel like a different application.
async function resolveTargets(supplied, kinds) {
  const ids = normaliseIds(supplied);
  if (ids.length === 0) {
    const current = await selection.get();
    ids.push(...current.ids);
  }
  if (ids.length === 0) {
    const { entities } = await doc.query({ kinds, limit: 100000 });
    return entities.map((entity) => entity.id);
  }
  if (!kinds) return ids;

  const wanted = new Set(kinds);
  const kept = [];
  for (const id of ids) {
    const entity = await doc.entity(id);
    if (wanted.has(entity.kind)) kept.push(id);
  }
  return kept;
}

function normaliseIds(value) {
  if (value === null || value === undefined) return [];
  const list = Array.isArray(value) ? value : [value];
  return list.map(idOf).filter((id) => Number.isInteger(id));
}

function idOf(value) {
  if (typeof value === 'number') return value;
  if (value && typeof value === 'object' && typeof value.id === 'number') {
    return value.id;
  }
  return Number(value);
}

function verticesOf(entity) {
  if (entity.points) {
    return entity.closed ? [...entity.points, entity.points[0]] : entity.points;
  }
  if (entity.start && entity.end) return [entity.start, entity.end];
  return [];
}

function fixed(value) {
  return Number(value.toFixed(3)).toString();
}

function plural(count, one, many) {
  return count === 1 ? one : (many ?? `${one}s`);
}

activate();
