part of '../dwg_reader.dart';

bool _printable(String value) =>
    value.length < 4096 &&
    value.runes.every((unit) => unit >= 0x20 && unit != 0x7f);

extension on DwgReader {
  /// Decodes the payload of a non-entity object we can model cheaply.
  ///
  /// Returns null for objects that stay stubs; the caller still records their
  /// handle and type so the object census matches the reference decoder.
  DwgObject? _readOtherObject(
    DwgBitReader br,
    int handle,
    int type,
    String typeName,
    int objectStartBit,
    int bitsize,
    int? limit,
  ) {
    final reactors = br.bl();
    final xdicMissing = _version >= 2004 ? br.b() != 0 : false;
    if (_version >= 2013) br.b(); // has_ds_data

    DwgBitReader? openHandles() {
      if (bitsize <= 0) return null;
      final at = objectStartBit + bitsize;
      if (at >= (limit ?? _data.length * 8)) return null;
      final h = DwgBitReader(_data)
        ..bitPos = at
        ..limitBits = limit;
      h.h(); // owner
      for (var i = 0; i < reactors && i < 10000; i++) {
        h.h();
      }
      if (_version >= 2004) {
        if (!xdicMissing) h.h();
      } else {
        h.h(); // xdic
      }
      return h;
    }

    Map<String, Object?> values = const {};
    switch (typeName) {
      case 'XRECORD':
        final xdataSize = br.bl();
        final xdata = _readXrecordXdata(br, xdataSize);
        if (xdata == null) return null;
        values = {
          'xdata_size': xdataSize,
          'xdata': xdata,
          'cloning': _version >= 2000 ? br.bs() : 1,
        };
      case 'DICTIONARY':
      case 'DICTIONARYWDFLT':
        final numItems = br.bl();
        if (numItems < 0 || numItems > 10000) return null;
        final int cloning;
        final int isHardOwner;
        if (typeName == 'DICTIONARYWDFLT') {
          // DICTIONARYWDFLT carries both bytes on every supported version.
          cloning = br.bs();
          isHardOwner = br.rc();
        } else {
          cloning = _version >= 2000 ? br.bs() : 0;
          isHardOwner = _version >= 14 || (_version == 13 && _maintVersion > 4)
              ? br.rc()
              : 0;
        }
        final names = <String>[];
        for (var i = 0; i < numItems; i++) {
          names.add(_text(br));
        }
        if (!br.ok) return null;
        // A damaged string stream can return control-filled runs. Keep the
        // object as a census stub rather than exposing garbage keys.
        if (names.any((name) => !_printable(name))) return null;
        final h = openHandles();
        final entries = <int>[];
        if (h != null) {
          for (var i = 0; i < numItems; i++) {
            entries.add(_handleOf(h, handle));
          }
        }
        final items = <String, int>{
          for (var i = 0; i < names.length; i++)
            names[i]: i < entries.length ? entries[i] : 0,
        };
        values = {
          'numitems': numItems,
          'cloning': cloning,
          'is_hardowner': isHardOwner,
          'items': items,
        };
        if (typeName == 'DICTIONARYWDFLT' && h != null) {
          values = {...values, 'defaultid': _handleOf(h, handle)};
        }
      case 'DICTIONARYVAR':
        values = {'schema': br.rc(), 'strvalue': _text(br)};
      case 'SCALE':
        final flag = br.bs();
        final name = _text(br);
        if (!_printable(name)) return null;
        values = {
          'flag': flag,
          'name': name,
          'paper_units': br.bd(),
          'drawing_units': br.bd(),
          'is_unit_scale': br.b(),
        };
      case 'BLOCK_CONTROL':
      case 'LAYER_CONTROL':
      case 'STYLE_CONTROL':
      case 'VIEW_CONTROL':
      case 'LTYPE_CONTROL':
      case 'UCS_CONTROL':
      case 'VPORT_CONTROL':
      case 'APPID_CONTROL':
      case 'VX_CONTROL':
      case 'DIMSTYLE_CONTROL':
        final numEntries = switch (typeName) {
          'BLOCK_CONTROL' ||
          'LAYER_CONTROL' ||
          'STYLE_CONTROL' ||
          'VIEW_CONTROL' => br.bl(),
          _ => br.bs(),
        };
        if (numEntries < 0 || numEntries > 10000) return null;
        final numMore = typeName == 'DIMSTYLE_CONTROL' && _version >= 2000
            ? br.rc()
            : 0;
        final h = numEntries > 0 || numMore > 0 ? openHandles() : null;
        final entries = <int>[];
        final extra = <String, Object?>{};
        if (h != null) {
          for (var i = 0; i < numEntries; i++) {
            entries.add(_handleOf(h, handle));
          }
          if (typeName == 'BLOCK_CONTROL') {
            extra['model_space'] = _handleOf(h, handle);
            extra['paper_space'] = _handleOf(h, handle);
          } else if (typeName == 'LTYPE_CONTROL') {
            extra['byblock'] = _handleOf(h, handle);
            extra['bylayer'] = _handleOf(h, handle);
          } else if (typeName == 'DIMSTYLE_CONTROL') {
            extra['morehandles'] = [
              for (var i = 0; i < numMore; i++) _handleOf(h, handle),
            ];
          }
        }
        values = {'entries': entries, ...extra};
      case 'MLEADERSTYLE':
        final classVersion = _version >= 2010 ? br.bs() : 2;
        final contentType = br.bs();
        final mleaderOrder = br.bs();
        final leaderOrder = br.bs();
        final maxPoints = br.bl();
        final firstSegAngle = br.bd();
        final secondSegAngle = br.bd();
        final type = br.bs();
        final lineColor = _readObjectCmc(br);
        final lineWt = _signedLong(br.bl());
        final hasLanding = br.b();
        final landingGap = br.bd();
        final hasDogleg = br.b();
        final landingDist = br.bd();
        final description = _text(br);
        if (!_printable(description)) return null;
        final arrowHeadSize = br.bd();
        final textDefault = _text(br);
        if (!_printable(textDefault)) return null;
        final attachLeft = br.bs();
        final attachRight = br.bs();
        var textAngleType = 0;
        if (classVersion >= 2) textAngleType = br.bs();
        final textAlignType = br.bs();
        final textColor = _readObjectCmc(br);
        final textHeight = br.bd();
        final hasTextFrame = br.b();
        var textAlwaysLeft = false;
        if (classVersion >= 2) textAlwaysLeft = br.b() != 0;
        final alignSpace = br.bd();
        final blockColor = _readObjectCmc(br);
        final blockScale = [br.bd(), br.bd(), br.bd()];
        final useBlockScale = br.b();
        final blockRotation = br.bd();
        final useBlockRotation = br.b();
        final blockConnection = br.bs();
        final scale = br.bd();
        final isChanged = br.b();
        final isAnnotative = br.b();
        final breakSize = br.bd();
        var attachDir = 0;
        var attachTop = 0;
        var attachBottom = 0;
        if (_version >= 2010) {
          attachDir = br.bs();
          attachTop = br.bs();
          attachBottom = br.bs();
        }
        var textExtended = false;
        if (_version >= 2013) textExtended = br.b() != 0;
        if (!br.ok) return null;
        final h = openHandles();
        values = {
          'class_version': classVersion,
          'content_type': contentType,
          'mleader_order': mleaderOrder,
          'leader_order': leaderOrder,
          'max_points': maxPoints,
          'first_seg_angle': firstSegAngle,
          'second_seg_angle': secondSegAngle,
          'type': type,
          'line_color': lineColor,
          'linewt': lineWt,
          'has_landing': hasLanding,
          'landing_gap': landingGap,
          'has_dogleg': hasDogleg,
          'landing_dist': landingDist,
          'description': description,
          'arrow_head_size': arrowHeadSize,
          'text_default': textDefault,
          'attach_left': attachLeft,
          'attach_right': attachRight,
          'text_angle_type': textAngleType,
          'text_align_type': textAlignType,
          'text_color': textColor,
          'text_height': textHeight,
          'has_text_frame': hasTextFrame,
          'text_always_left': textAlwaysLeft,
          'align_space': alignSpace,
          'block_color': blockColor,
          'block_scale': blockScale,
          'use_block_scale': useBlockScale,
          'block_rotation': blockRotation,
          'use_block_rotation': useBlockRotation,
          'block_connection': blockConnection,
          'scale': scale,
          'is_changed': isChanged,
          'is_annotative': isAnnotative,
          'break_size': breakSize,
          'attach_dir': attachDir,
          'attach_top': attachTop,
          'attach_bottom': attachBottom,
          'text_extended': textExtended,
        };
        if (h != null) {
          values['line_type'] = _handleOf(h, handle);
          values['arrow_head'] = _handleOf(h, handle);
          values['text_style'] = _handleOf(h, handle);
          values['block'] = _handleOf(h, handle);
        }
      case 'MLINESTYLE':
        final name = _text(br);
        final description = _text(br);
        if (!_printable(name)) return null;
        final flag = br.bs();
        final fillColor = _readObjectCmc(br);
        final startAngle = br.bd();
        final endAngle = br.bd();
        final numLines = br.rc();
        if (numLines < 0 || numLines > 1000) return null;
        final lines = <Map<String, Object?>>[];
        for (var i = 0; i < numLines; i++) {
          final offset = br.bd();
          final line = <String, Object?>{
            'offset': offset,
            'color': _readObjectCmc(br),
          };
          if (_version < 2018) {
            line['lt_index'] = _signedShort(br.bs());
          }
          lines.add(line);
        }
        if (!br.ok) return null;
        if (_version >= 2018 && numLines > 0) {
          final h = openHandles();
          if (h != null) {
            for (var i = 0; i < numLines; i++) {
              lines[i]['lt_ltype'] = _handleOf(h, handle);
            }
          }
        }
        values = {
          'name': name,
          'description': description,
          'flag': flag,
          'fill_color': fillColor,
          'start_angle': startAngle,
          'end_angle': endAngle,
          'lines': lines,
        };
      case 'PROXY_OBJECT':
        {
          // Pre-R2000 proxy bitsize is relative to the object address, which
          // this reader does not track; keep those rare proxies as stubs.
          if (_version < 2000) return null;
          final proxy = <String, Object?>{};
          proxy['class_id'] = br.bl();
          if (_version >= 2018) {
            final dwgVersion = br.bl();
            final maintVersion = br.bl();
            proxy['dwg_version'] = dwgVersion;
            proxy['maint_version'] = maintVersion;
            proxy['version'] = (maintVersion << 8) + dwgVersion;
          } else {
            final version = br.bl();
            proxy['version'] = version;
            proxy['maint_version'] = version >> 8;
            proxy['dwg_version'] = version & 0xff;
          }
          if (_version >= 2000) proxy['from_dxf'] = br.b();
          final dataBits = objectStartBit + bitsize - br.bitPos;
          proxy['data_numbits'] = dataBits;
          if (dataBits > 0 && dataBits < 1 << 24) {
            final buffer = StringBuffer();
            var left = dataBits;
            while (left >= 8 && br.ok) {
              buffer.write(br.rc().toRadixString(16).padLeft(2, '0'));
              left -= 8;
            }
            if (left > 0 && br.ok) {
              final bits = br.bits(left);
              var reversed = 0;
              for (var i = 0; i < left; i++) {
                reversed = (reversed << 1) | ((bits >> i) & 1);
              }
              buffer.write(reversed.toRadixString(16).padLeft(2, '0'));
            }
            proxy['data'] = buffer.toString().toUpperCase();
          }
          values = proxy;
        }
      case 'RENDERGLOBAL':
        values = {
          'class_version': br.bl(),
          'procedure': br.bl(),
          'destination': br.bl(),
          'save_enabled': br.b(),
          'save_filename': _text(br),
          'image_width': br.bl(),
          'image_height': br.bl(),
          'predef_presets_first': br.b(),
          'highlevel_info': br.b(),
        };
      case 'RENDERENTRY':
        values = {
          'class_version': br.bl(),
          'image_file_name': _text(br),
          'preset_name': _text(br),
          'view_name': _text(br),
          'dimension_x': br.bl(),
          'dimension_y': br.bl(),
          'start_year': br.bs(),
          'start_month': br.bs(),
          'start_day': br.bs(),
          'start_hour': br.bs(),
          'start_minute': br.bs(),
          'start_second': br.bs(),
          'start_msec': br.bs(),
          'end_year': br.bs(),
          'end_month': br.bs(),
          'end_day': br.bs(),
          'end_hour': br.bs(),
          'end_minute': br.bs(),
          'end_second': br.bs(),
          'end_msec': br.bs(),
          'render_time': br.bd(),
          'memory_amount': br.bl(),
          'material_count': br.bl(),
          'light_count': br.bl(),
          'triangle_count': br.bl(),
          'display_index': br.bl(),
        };
      case 'RENDERSETTINGS':
      case 'RAPIDRTRENDERSETTINGS':
      case 'MENTALRAYRENDERSETTINGS':
        {
          final render = <String, Object?>{};
          _readRenderSettings(br, render);
          if (typeName == 'RENDERSETTINGS') {
            if (_version >= 2013) render['has_predefined'] = br.b();
          } else if (typeName == 'RAPIDRTRENDERSETTINGS') {
            render['rapidrt_version'] = br.bl();
            render['render_target'] = br.bl();
            render['render_level'] = br.bl();
            render['render_time'] = br.bl();
            render['lighting_model'] = br.bl();
            render['filter_type'] = br.bl();
            render['filter_width'] = br.bd();
            render['filter_height'] = br.bd();
            render['has_predefined'] = br.b();
          } else {
            render['mr_version'] = br.bl();
            render['sampling_min'] = br.bl();
            render['sampling_max'] = br.bl();
            render['sampling_mr_filter'] = br.bs();
            render['sampling_filter1'] = br.bd();
            render['sampling_filter2'] = br.bd();
            render['sampling_contrast_color1'] = br.bd();
            render['sampling_contrast_color2'] = br.bd();
            render['sampling_contrast_color3'] = br.bd();
            render['sampling_contrast_color4'] = br.bd();
            render['shadow_mode'] = br.bs();
            render['shadow_maps_enabled'] = br.b();
            render['ray_tracing_enabled'] = br.b();
            render['ray_trace_depth1'] = br.bl();
            render['ray_trace_depth2'] = br.bl();
            render['ray_trace_depth3'] = br.bl();
            render['global_illumination_enabled'] = br.b();
            render['gi_sample_count'] = br.bl();
            render['gi_sample_radius_enabled'] = br.b();
            render['gi_sample_radius'] = br.bd();
            render['gi_photons_per_light'] = br.bl();
            render['photon_trace_depth1'] = br.bl();
            render['photon_trace_depth2'] = br.bl();
            render['photon_trace_depth3'] = br.bl();
            render['final_gathering_enabled'] = br.b();
            render['fg_ray_count'] = br.bl();
            render['fg_sample_radius_state1'] = br.b();
            render['fg_sample_radius_state2'] = br.b();
            render['fg_sample_radius_state3'] = br.b();
            render['fg_sample_radius1'] = br.bd();
            render['fg_sample_radius2'] = br.bd();
            render['light_luminance_scale'] = br.bd();
            render['diagnostics_mode'] = br.bs();
            render['diagnostics_grid_mode'] = br.bs();
            render['diagnostics_grid_float'] = br.bd();
            render['diagnostics_photon_mode'] = br.bs();
            render['diagnostics_bsp_mode'] = br.bs();
            render['export_mi_enabled'] = br.b();
            render['mr_description'] = _text(br);
            render['tile_size'] = br.bl();
            render['tile_order'] = br.bs();
            render['memory_limit'] = br.bl();
            render['diagnostics_samples_mode'] = br.b();
            render['energy_multiplier'] = br.bd();
          }
          values = render;
        }
      case 'RASTERVARIABLES':
        values = {
          'class_version': br.bl(),
          'image_frame': br.bs(),
          'image_quality': br.bs(),
          'units': br.bs(),
        };
      case 'WIPEOUTVARIABLES':
        values = {'display_frame': br.bs()};
      case 'BLOCKREPRESENTATION':
      case 'DYNAMICBLOCKPURGEPREVENTER':
        {
          final flag = br.bs();
          final blockHandles = openHandles();
          final block = blockHandles == null
              ? 0
              : _handleOf(blockHandles, handle);
          values = {'flag': flag, 'block': block};
        }
      case 'SUN':
        values = {
          'class_version': br.bl(),
          'is_on': br.b(),
          'color': _readObjectCmc(br),
          'intensity': br.bd(),
          'has_shadow': br.b(),
          'julian_day': br.bl(),
          'msecs': br.bl(),
          'is_dst': br.b(),
          'shadow_type': br.bl(),
          'shadow_mapsize': br.bs(),
          'shadow_softness': br.rc(),
        };
      case 'LEADEROBJECTCONTEXTDATA':
        {
          final classVersion = br.bs();
          final isDefault = br.b();
          final numPoints = br.bl();
          if (numPoints < 0 || numPoints > 100000) return null;
          final points = <List<double>>[
            for (var i = 0; i < numPoints; i++) [br.bd(), br.bd(), br.bd()],
          ];
          final xDirection = [br.bd(), br.bd(), br.bd()];
          final b290 = br.b();
          final insptOffset = [br.bd(), br.bd(), br.bd()];
          final endptProj = [br.bd(), br.bd(), br.bd()];
          if (!br.ok) return null;
          final leaderHandles = openHandles();
          values = {
            'class_version': classVersion,
            'is_default': isDefault,
            'num_points': numPoints,
            'points': points,
            'x_direction': xDirection,
            'b290': b290,
            'inspt_offset': insptOffset,
            'endptproj': endptProj,
          };
          if (leaderHandles != null) {
            values['scale'] = _handleOf(leaderHandles, handle);
          }
        }
      case 'ASSOCACTION':
      case 'ASSOCNETWORK':
      case 'ASSOCVARIABLE':
        {
          final assoc = <String, Object?>{};
          final pending = <void Function(int)>[];
          _readAssocAction(br, assoc, pending);
          if (typeName == 'ASSOCNETWORK') {
            assoc['network_version'] = br.bs();
            assoc['network_action_index'] = br.bl();
            final numActions = br.bl();
            if (numActions < 0 || numActions > 10000) return null;
            final actions = <Map<String, Object?>>[];
            for (var i = 0; i < numActions; i++) {
              final action = <String, Object?>{'is_owned': br.b()};
              pending.add((h) => action['dep'] = h);
              actions.add(action);
            }
            assoc['actions'] = actions;
            final numOwned = br.bl();
            if (numOwned < 0 || numOwned > 10000) return null;
            final owned = <int>[];
            for (var i = 0; i < numOwned; i++) {
              pending.add((h) => owned.add(h));
            }
            assoc['owned_actions'] = owned;
          } else if (typeName == 'ASSOCVARIABLE') {
            assoc['av_class_version'] = br.bl();
            assoc['name'] = _text(br);
            assoc['expression'] = _text(br);
            assoc['evaluator'] = _text(br);
            assoc['desc'] = _text(br);
            _readAssocVariant(br, assoc, '', pending);
            final hasCached = br.b();
            assoc['has_cached_value'] = hasCached;
            if (hasCached != 0) assoc['cached_value'] = _text(br);
            assoc['flag'] = br.b();
            final numVarDeps = br.bl();
            if (numVarDeps < 0 || numVarDeps > 10000) return null;
            final varDeps = <Map<String, Object?>>[];
            for (var i = 0; i < numVarDeps; i++) {
              final dep = <String, Object?>{};
              pending.add((h) => dep['dependency'] = h);
              dep['flags'] = br.bl();
              varDeps.add(dep);
            }
            assoc['var_deps'] = varDeps;
          }
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null) {
            for (final setter in pending) {
              setter(_handleOf(h, handle));
            }
          }
          values = assoc;
        }
      case 'ACSH_HISTORY_CLASS':
        {
          final history = <String, Object?>{};
          final pending = <void Function(int)>[];
          history['major'] = br.bl();
          history['minor'] = br.bl();
          pending.add((h) => history['owner'] = h);
          history['h_nodeid'] = br.bl();
          history['show_history'] = br.b();
          history['record_history'] = br.b();
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null) {
            for (final setter in pending) {
              setter(_handleOf(h, handle));
            }
          }
          values = history;
        }
      case 'ACSH_BOX_CLASS':
      case 'ACSH_WEDGE_CLASS':
      case 'ACSH_SPHERE_CLASS':
      case 'ACSH_CYLINDER_CLASS':
      case 'ACSH_CONE_CLASS':
      case 'ACSH_TORUS_CLASS':
      case 'ACSH_FILLET_CLASS':
      case 'ACSH_CHAMFER_CLASS':
        {
          final sh = <String, Object?>{};
          final pending = <void Function(int)>[];
          _readEvalExprFields(br, 'evalexpr.', sh, pending);
          _readHistoryNode(br, sh, pending);
          sh['major'] = br.bl();
          sh['minor'] = br.bl();
          if (typeName == 'ACSH_BOX_CLASS' || typeName == 'ACSH_WEDGE_CLASS') {
            sh['length'] = br.bd();
            sh['width'] = br.bd();
            sh['height'] = br.bd();
          } else if (typeName == 'ACSH_SPHERE_CLASS') {
            sh['radius'] = br.bd();
          } else if (typeName == 'ACSH_CYLINDER_CLASS' ||
              typeName == 'ACSH_CONE_CLASS') {
            sh['height'] = br.bd();
            sh['major_radius'] = br.bd();
            sh['minor_radius'] = br.bd();
            sh['x_radius'] = br.bd();
          } else if (typeName == 'ACSH_TORUS_CLASS') {
            sh['major_radius'] = br.bd();
            sh['minor_radius'] = br.bd();
          } else if (typeName == 'ACSH_FILLET_CLASS') {
            sh['method'] = br.bl();
            final numEdges = br.bl();
            if (numEdges < 0 || numEdges > 100000) return null;
            sh['edges'] = [for (var i = 0; i < numEdges; i++) br.bl()];
            final numRadiuses = br.bl();
            if (numRadiuses < 0 || numRadiuses > 100000) return null;
            sh['radiuses'] = [for (var i = 0; i < numRadiuses; i++) br.bd()];
            final numStart = br.bl();
            final numEnd = br.bl();
            if (numStart < 0 ||
                numStart > 100000 ||
                numEnd < 0 ||
                numEnd > 100000) {
              return null;
            }
            sh['endsetbacks'] = [for (var i = 0; i < numEnd; i++) br.bd()];
            sh['startsetbacks'] = [for (var i = 0; i < numStart; i++) br.bd()];
          } else {
            sh['method'] = br.bl();
            sh['base_dist'] = br.bd();
            sh['other_dist'] = br.bd();
            final numEdges = br.bl();
            if (numEdges < 0 || numEdges > 100000) return null;
            sh['edges'] = [for (var i = 0; i < numEdges; i++) br.bl()];
            sh['base_face'] = br.bl();
          }
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null) {
            for (final setter in pending) {
              setter(_handleOf(h, handle));
            }
          }
          values = sh;
        }
      case 'VX_TABLE_RECORD':
        {
          final vx = <String, Object?>{'name': _text(br)};
          if (_version < 2004) {
            vx['is_xref_ref'] = br.b();
            vx['is_xref_resolved'] = br.bs();
            vx['is_xref_dep'] = br.b();
          } else {
            vx['is_xref_ref'] = 1;
            final resolved = br.bs();
            vx['is_xref_resolved'] = resolved;
            vx['is_xref_dep'] = resolved == 256 ? 1 : 0;
          }
          final pending = <void Function(int)>[(h) => vx['xref'] = h];
          final isOn = br.b();
          vx['is_on'] = isOn;
          pending.add((h) => vx['viewport'] = h);
          pending.add((h) => vx['prev_entry'] = h);
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null) {
            for (final setter in pending) {
              setter(_handleOf(h, handle));
            }
          }
          values = vx;
        }
      case 'ASSOCDIMDEPENDENCYBODY':
        values = {
          'adb_version': br.bs(),
          'dimbase_version': br.bs(),
          'name': _text(br),
          'class_version': br.bs(),
        };
      case 'ASSOCVALUEDEPENDENCY':
        {
          final dep = <String, Object?>{};
          final pending = <void Function(int)>[];
          dep['assocdep.class_version'] = br.bs();
          dep['assocdep.status'] = br.bl();
          dep['assocdep.is_read_dep'] = br.b();
          dep['assocdep.is_write_dep'] = br.b();
          dep['assocdep.is_attached_to_object'] = br.b();
          dep['assocdep.is_delegating_to_owning_action'] = br.b();
          dep['assocdep.order'] = _signedLong(br.bl());
          pending.add((h) => dep['assocdep.dep_on'] = h);
          final hasName = br.b();
          dep['assocdep.has_name'] = hasName;
          if (hasName != 0) dep['assocdep.name'] = _text(br);
          pending.add((h) => dep['assocdep.readdep'] = h);
          pending.add((h) => dep['assocdep.node'] = h);
          pending.add((h) => dep['assocdep.dep_body'] = h);
          dep['assocdep.depbodyid'] = _signedLong(br.bl());
          dep['class_version'] = br.bl();
          dep['name'] = _text(br);
          _readAssocVariant(br, dep, '', pending);
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null) {
            for (final setter in pending) {
              setter(_handleOf(h, handle));
            }
          }
          values = dep;
        }
      case 'ASSOCDEPENDENCY':
      case 'ASSOCGEOMDEPENDENCY':
        {
          final geom = typeName == 'ASSOCGEOMDEPENDENCY';
          final prefix = geom ? 'assocdep.' : '';
          final dep = <String, Object?>{};
          final pending = <void Function(int)>[];
          dep['${prefix}class_version'] = br.bs();
          dep['${prefix}status'] = br.bl();
          dep['${prefix}is_read_dep'] = br.b();
          dep['${prefix}is_write_dep'] = br.b();
          dep['${prefix}is_attached_to_object'] = br.b();
          dep['${prefix}is_delegating_to_owning_action'] = br.b();
          dep['${prefix}order'] = _signedLong(br.bl());
          pending.add((h) => dep['${prefix}dep_on'] = h);
          final hasName = br.b();
          dep['${prefix}has_name'] = hasName;
          if (hasName != 0) dep['${prefix}name'] = _text(br);
          pending.add((h) => dep['${prefix}readdep'] = h);
          pending.add((h) => dep['${prefix}node'] = h);
          pending.add((h) => dep['${prefix}dep_body'] = h);
          dep['${prefix}depbodyid'] = _signedLong(br.bl());
          if (geom) {
            dep['class_version'] = br.bs();
            dep['enabled'] = br.b();
            if (_version >= 2013) {
              final hasClassname = br.b();
              dep['has_classname'] = hasClassname;
              final classCode = br.bl();
              dep['class_code'] = classCode;
              dep['values'] = <int>[
                if (classCode == 3)
                  for (var i = 0; i < 3; i++) br.bl(),
              ];
            } else {
              dep['classname'] = _text(br);
            }
            dep['dependent_on_compound_object'] = br.b();
          }
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null) {
            for (final setter in pending) {
              setter(_handleOf(h, handle));
            }
          }
          values = dep;
        }
      case 'BLOCKVISIBILITYGRIP':
        {
          final grip = <String, Object?>{};
          final pending = <void Function(int)>[];
          _readEvalExprFields(br, 'evalexpr.', grip, pending);
          grip['name'] = _text(br);
          grip['be_major'] = br.bl();
          grip['be_minor'] = br.bl();
          grip['eed1071'] = br.bl();
          grip['bg_bl91'] = br.bl();
          grip['bg_bl92'] = br.bl();
          grip['bg_location'] = [br.bd(), br.bd(), br.bd()];
          grip['bg_insert_cycling'] = br.b();
          grip['bg_insert_cycling_weight'] = _signedLong(br.bl());
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null) {
            for (final setter in pending) {
              setter(_handleOf(h, handle));
            }
          }
          values = grip;
        }
      case 'BLOCKVISIBILITYPARAMETER':
        {
          final params = <String, Object?>{};
          final pending = <void Function(int)>[];
          _readEvalExprFields(br, 'evalexpr.', params, pending);
          params['name'] = _text(br);
          params['be_major'] = br.bl();
          params['be_minor'] = br.bl();
          params['eed1071'] = br.bl();
          params['show_properties'] = br.b();
          params['chain_actions'] = br.b();
          params['def_pt'] = [br.bd(), br.bd(), br.bd()];
          for (var prop = 1; prop <= 2; prop++) {
            final numConnections = br.bl();
            if (numConnections < 0 || numConnections > 10000) return null;
            final connections = <Map<String, Object?>>[];
            for (var i = 0; i < numConnections; i++) {
              connections.add({'code': br.bl(), 'name': _text(br)});
            }
            params['prop$prop.connections'] = connections;
          }
          params['num_propinfos'] = br.bl();
          params['is_initialized'] = br.b();
          params['blockvisi_name'] = _text(br);
          params['blockvisi_desc'] = _text(br);
          params['unknown_bool'] = br.b();
          final numBlocks = br.bl();
          if (numBlocks < 0 || numBlocks > 100000) return null;
          final blocks = <int>[];
          for (var i = 0; i < numBlocks; i++) {
            pending.add((h) => blocks.add(h));
          }
          params['blocks'] = blocks;
          final numStates = br.bl();
          if (numStates < 0 || numStates > 100000) return null;
          final states = <Map<String, Object?>>[];
          for (var i = 0; i < numStates; i++) {
            final state = <String, Object?>{'name': _text(br)};
            final stateBlocks = <int>[];
            final count = br.bl();
            if (count < 0 || count > 100000) return null;
            for (var j = 0; j < count; j++) {
              pending.add((h) => stateBlocks.add(h));
            }
            state['blocks'] = stateBlocks;
            final stateParams = <int>[];
            final numParams = br.bl();
            if (numParams < 0 || numParams > 100000) return null;
            for (var j = 0; j < numParams; j++) {
              pending.add((h) => stateParams.add(h));
            }
            state['params'] = stateParams;
            states.add(state);
          }
          params['states'] = states;
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null) {
            for (final setter in pending) {
              setter(_handleOf(h, handle));
            }
          }
          values = params;
        }
      case 'BLOCKGRIPLOCATIONCOMPONENT':
        {
          final parentId = _signedLong(br.bl());
          final major = br.bl();
          final minor = br.bl();
          final valueCode = _signedShort(br.bs());
          final grip = <String, Object?>{
            'evalexpr.parentid': parentId,
            'evalexpr.major': major,
            'evalexpr.minor': minor,
            'evalexpr.value_code': valueCode,
          };
          switch (valueCode) {
            case 40:
              grip['evalexpr.value.num40'] = br.bd();
            case 10:
              grip['evalexpr.value.pt2d'] = [br.rd(), br.rd()];
            case 11:
              grip['evalexpr.value.pt3d'] = [br.rd(), br.rd()];
            case 1:
              grip['evalexpr.value.text1'] = _text(br);
            case 90:
              grip['evalexpr.value.long90'] = br.bl();
            case 91:
              grip['evalexpr.value.handle91'] = 0;
            case 70:
              grip['evalexpr.value.short70'] = br.bs();
            default:
              break;
          }
          grip['evalexpr.nodeid'] = br.bl();
          grip['grip_type'] = br.bl();
          grip['grip_expr'] = _text(br);
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null && valueCode == 91) {
            grip['evalexpr.value.handle91'] = _handleOf(h, handle);
          }
          values = grip;
        }
      case 'MTEXTATTRIBUTEOBJECTCONTEXTDATA':
        {
          final classVersion = br.bs();
          final isDefault = br.b();
          final horizontalMode = br.bs();
          final rotation = br.bd();
          final insPt = [br.rd(), br.rd()];
          final alignmentPt = [br.rd(), br.rd()];
          final enableContext = br.b();
          final context = <String, Object?>{
            'class_version': classVersion,
            'is_default': isDefault,
            'horizontal_mode': horizontalMode,
            'rotation': rotation,
            'ins_pt': insPt,
            'alignment_pt': alignmentPt,
            'enable_context': enableContext,
          };
          if (enableContext != 0) {
            context['context.flag'] = br.bs();
            context['context.name'] = _text(br);
            context['context.paper_units'] = br.bd();
            context['context.drawing_units'] = br.bd();
            context['context.is_unit_scale'] = br.b();
          }
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null) context['scale'] = _handleOf(h, handle);
          values = context;
        }
      case 'ALDIMOBJECTCONTEXTDATA':
        final classVersion = br.bs();
        final isDefault = br.b();
        final defPt = [br.rd(), br.rd()];
        final isDefTextloc = br.b();
        final textRotation = br.bd();
        final b293 = br.b();
        final dimtofl = br.b();
        final dimosxd = br.b();
        final dimatfit = br.b();
        final dimtix = br.b();
        final dimtmove = br.b();
        final overrideCode = br.rc();
        final hasArrow2 = br.b();
        final flipArrow2 = br.b();
        final flipArrow1 = br.b();
        final dimlinePt = [br.bd(), br.bd(), br.bd()];
        if (!br.ok) return null;
        final aldimHandles = openHandles();
        values = {
          'class_version': classVersion,
          'is_default': isDefault,
          'dimension.def_pt': defPt,
          'dimension.is_def_textloc': isDefTextloc,
          'dimension.text_rotation': textRotation,
          'dimension.b293': b293,
          'dimension.dimtofl': dimtofl,
          'dimension.dimosxd': dimosxd,
          'dimension.dimatfit': dimatfit,
          'dimension.dimtix': dimtix,
          'dimension.dimtmove': dimtmove,
          'dimension.override_code': overrideCode,
          'dimension.has_arrow2': hasArrow2,
          'dimension.flip_arrow2': flipArrow2,
          'dimension.flip_arrow1': flipArrow1,
          'dimline_pt': dimlinePt,
        };
        if (aldimHandles != null) {
          values['scale'] = _handleOf(aldimHandles, handle);
          values['dimension.block'] = _handleOf(aldimHandles, handle);
        }
      case 'EVALUATION_GRAPH':
        {
          final firstNodeId = br.bl();
          final firstNodeIdCopy = br.bl();
          final numNodes = br.bl();
          if (numNodes < 0 || numNodes > 100000) return null;
          final nodes = <Map<String, Object?>>[];
          final nodeHandles = <void Function(int)>[];
          for (var i = 0; i < numNodes; i++) {
            final id = br.bl();
            final edgeFlags = br.bl();
            if (edgeFlags != 32) break;
            final node = <String, Object?>{
              'id': id,
              'edge_flags': edgeFlags,
              'nextid': br.bl(),
            };
            nodeHandles.add((h) => node['evalexpr'] = h);
            node['node'] = [for (var j = 0; j < 4; j++) _signedLong(br.bl())];
            nodes.add(node);
          }
          final numEdges = br.bl();
          if (numEdges < 0 || numEdges > 100000) return null;
          final edges = <Map<String, Object?>>[];
          for (var i = 0; i < numEdges; i++) {
            final edge = <String, Object?>{
              'id': br.bl(),
              'nextid': _signedLong(br.bl()),
              'incoming_edge': _signedLong(br.bl()),
              'source_node': _signedLong(br.bl()),
              'destination_node': _signedLong(br.bl()),
            };
            for (var j = 0; j < 5; j++) {
              edge['out_edge[$j]'] = _signedLong(br.bl());
            }
            edges.add(edge);
          }
          if (!br.ok) return null;
          final graphHandles = openHandles();
          if (graphHandles != null) {
            for (final setter in nodeHandles) {
              setter(_handleOf(graphHandles, handle));
            }
          }
          values = {
            'first_nodeid': firstNodeId,
            'first_nodeid_copy': firstNodeIdCopy,
            'nodes': nodes,
            'edges': edges,
          };
        }
      case 'TABLESTYLE':
      case 'CELLSTYLEMAP':
        {
          final valuesMap = <String, Object?>{};
          final pending = <void Function(int)>[];
          if (typeName == 'TABLESTYLE' && _version < 2010) {
            // R2007 stores extra per-row data that the reference decoder does not decode,
            // so its output for these objects is unusable; keep a stub.
            if (_version >= 2007) return null;
            valuesMap['name'] = _text(br);
            valuesMap['flow_direction'] = br.bs();
            valuesMap['flags'] = br.bs();
            valuesMap['horiz_cell_margin'] = br.bd();
            valuesMap['vert_cell_margin'] = br.bd();
            valuesMap['is_title_suppressed'] = br.b();
            valuesMap['is_header_suppressed'] = br.b();
            final rowstyles = <Map<String, Object?>>[];
            for (var row = 0; row < 3; row++) {
              final style = <String, Object?>{};
              pending.add((handle) => style['text_style'] = handle);
              style['text_height'] = br.bd();
              style['text_alignment'] = br.bs();
              style['text_color'] = _readObjectCmtc(br);
              style['fill_color'] = _readObjectCmtc(br);
              style['has_bgcolor'] = br.b();
              final borders = <Map<String, Object?>>[];
              for (var i = 0; i < 6; i++) {
                borders.add({
                  'linewt': _signedShort(br.bs()),
                  'visible': br.b(),
                  'color': _readObjectCmtc(br),
                });
              }
              style['borders'] = borders;
              rowstyles.add(style);
            }
            valuesMap['rowstyles'] = rowstyles;
          } else if (typeName == 'TABLESTYLE') {
            valuesMap['unknown_rc'] = br.rc();
            valuesMap['name'] = _text(br);
            valuesMap['unknown_bl1'] = br.bl();
            valuesMap['unknown_bl2'] = br.bl();
            pending.add(
              (handle) =>
                  valuesMap['cellstyle'] = [handle, handle, handle, handle],
            );
            _readCellStyle(br, 'sty.cellstyle', valuesMap, pending);
            valuesMap['sty.id'] = br.bl();
            valuesMap['sty.type'] = br.bl();
            valuesMap['sty.name'] = _text(br);
            final numOverrides = br.bl();
            valuesMap['numoverrides'] = numOverrides;
            if (numOverrides < 0 || numOverrides > 1000) return null;
            if (numOverrides > 0) {
              valuesMap['unknown_bl3'] = br.bl();
              _readCellStyle(br, 'ovr.cellstyle', valuesMap, pending);
              valuesMap['ovr.id'] = br.bl();
              valuesMap['ovr.type'] = br.bl();
              valuesMap['ovr.name'] = _text(br);
            }
          } else {
            final numCells = br.bl();
            if (numCells < 0 || numCells > 10000) return null;
            final cells = <Map<String, Object?>>[];
            for (var i = 0; i < numCells; i++) {
              final cell = <String, Object?>{};
              _readCellStyle(br, 'cellstyle', cell, pending);
              cell['id'] = br.bl();
              cell['type'] = br.bl();
              cell['name'] = _text(br);
              cells.add(cell);
            }
            valuesMap['num_cells'] = numCells;
            valuesMap['cells'] = cells;
          }
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null) {
            for (final setter in pending) {
              setter(_handleOf(h, handle));
            }
          }
          values = valuesMap;
        }
      case 'SECTIONVIEWSTYLE':
      case 'DETAILVIEWSTYLE':
        {
          final detail = typeName == 'DETAILVIEWSTYLE';
          final mdocVersion = br.bs();
          final desc = _text(br);
          if (!_printable(desc)) return null;
          final isModified = br.b();
          final viewStyle = <String, Object?>{
            'mdoc_class_version': mdocVersion,
            'desc': desc,
            'is_modified_for_recompute': isModified,
          };
          if (_version >= 2018) {
            viewStyle['display_name'] = _text(br);
            viewStyle['viewstyle_flags'] = br.bl();
          }
          viewStyle['class_version'] = br.bs();
          viewStyle['flags'] = br.bl();
          viewStyle['identifier_color'] = _readObjectCmc(br);
          viewStyle['identifier_height'] = br.bd();
          if (!detail) {
            viewStyle['arrow_symbol_color'] = _readObjectCmc(br);
            viewStyle['arrow_symbol_size'] = br.bd();
          }
          viewStyle['identifier_exclude_characters'] = _text(br);
          if (detail) {
            viewStyle['identifier_offset'] = br.bd();
            viewStyle['identifier_placement'] = br.rc();
            viewStyle['arrow_symbol_color'] = _readObjectCmc(br);
            viewStyle['arrow_symbol_size'] = br.bd();
            viewStyle['boundary_linewt'] = _signedLong(br.bl());
            viewStyle['boundary_line_color'] = _readObjectCmc(br);
          } else {
            viewStyle['arrow_symbol_extension_length'] = br.bd();
            viewStyle['plane_linewt'] = _signedLong(br.bl());
            viewStyle['plane_line_color'] = _readObjectCmc(br);
            viewStyle['bend_linewt'] = _signedLong(br.bl());
            viewStyle['bend_line_color'] = _readObjectCmc(br);
            viewStyle['bend_line_length'] = br.bd();
            viewStyle['end_line_length'] = br.bd();
          }
          viewStyle['viewlabel_text_color'] = _readObjectCmc(br);
          viewStyle['viewlabel_text_height'] = br.bd();
          viewStyle['viewlabel_attachment'] = br.bl();
          viewStyle['viewlabel_offset'] = br.bd();
          viewStyle['viewlabel_alignment'] = br.bl();
          viewStyle['viewlabel_pattern'] = _text(br);
          if (detail) {
            viewStyle['connection_linewt'] = _signedLong(br.bl());
            viewStyle['connection_line_color'] = _readObjectCmc(br);
            viewStyle['borderline_linewt'] = _signedLong(br.bl());
            viewStyle['borderline_color'] = _readObjectCmc(br);
            viewStyle['model_edge'] = br.rc();
          } else {
            viewStyle['hatch_color'] = _readObjectCmc(br);
            viewStyle['hatch_bg_color'] = _readObjectCmc(br);
            viewStyle['hatch_pattern'] = _text(br);
            viewStyle['hatch_scale'] = br.bd();
            viewStyle['hatch_transparency'] = _signedLong(br.bl());
            viewStyle['unknown_b1'] = br.b();
            viewStyle['unknown_b2'] = br.b();
            viewStyle['identifier_position'] = _signedLong(br.bl());
            viewStyle['identifier_offset'] = br.bd();
            viewStyle['arrow_position'] = _signedLong(br.bl());
            viewStyle['end_line_overshoot'] = br.bd();
            final numAngles = br.bl();
            if (numAngles < 0 || numAngles > 10000) return null;
            viewStyle['num_hatch_angles'] = numAngles;
            viewStyle['hatch_angles'] = [
              for (var i = 0; i < numAngles; i++) br.bd(),
            ];
          }
          if (!br.ok) return null;
          final h = openHandles();
          if (h != null) {
            viewStyle['identifier_style'] = _handleOf(h, handle);
            if (detail) {
              viewStyle['arrow_symbol'] = _handleOf(h, handle);
              viewStyle['boundary_ltype'] = _handleOf(h, handle);
              viewStyle['viewlabel_text_style'] = _handleOf(h, handle);
              viewStyle['connection_ltype'] = _handleOf(h, handle);
              viewStyle['borderline_ltype'] = _handleOf(h, handle);
            } else {
              viewStyle['arrow_start_symbol'] = _handleOf(h, handle);
              viewStyle['arrow_end_symbol'] = _handleOf(h, handle);
              viewStyle['plane_ltype'] = _handleOf(h, handle);
              viewStyle['bend_ltype'] = _handleOf(h, handle);
              viewStyle['viewlabel_text_style'] = _handleOf(h, handle);
            }
          }
          values = viewStyle;
        }
      case 'SORTENTSTABLE':
        final numEnts = br.bl();
        if (numEnts < 0 || numEnts > 50000) return null;
        // The sort handles live in the object data, not the handle stream.
        final sortEnts = <int>[
          for (var i = 0; i < numEnts; i++) _handleOf(br, handle),
        ];
        if (!br.ok) return null;
        final sortHandles = openHandles();
        final table = <String, Object?>{
          'num_ents': numEnts,
          'sort_ents': sortEnts,
        };
        if (sortHandles != null) {
          table['block_owner'] = _handleOf(sortHandles, handle);
          table['ents'] = [
            for (var i = 0; i < numEnts; i++) _handleOf(sortHandles, handle),
          ];
        }
        values = table;
      case 'IMAGEDEF_REACTOR':
        values = {'class_version': br.bl()};
      case 'DIMASSOC':
        final associativity = br.bl();
        final transSpaceFlag = br.b();
        final rotatedType = br.rc();
        var mask = associativity & 0x3f;
        var bitCount = 0;
        while (mask != 0) {
          bitCount++;
          mask &= mask - 1;
        }
        final refs = <Map<String, Object?>>[];
        final refInfo =
            <
              ({int numXrefs, int numIntsectObject, Map<String, Object?> ref})
            >[];
        var consumed = 0;
        for (var slot = 0; slot < 6; slot++) {
          final previous = slot == 0
              ? 0
              : (refs[slot - 1]['has_lastpt_ref'] as int?) ?? 0;
          final due = slot == 0 || previous == 0;
          if (due) consumed++;
          if (due && consumed > bitCount) {
            refs.add(<String, Object?>{});
            continue;
          }
          final ref = <String, Object?>{};
          // The class name is a T string on R2004+.
          ref['classname'] = _text(br);
          final osnapType = br.rc();
          final numXrefs = br.bl();
          if (numXrefs < 0 || numXrefs > 10000) return null;
          ref['osnap_type'] = osnapType;
          ref['num_xrefs'] = numXrefs;
          if (osnapType != 0 && numXrefs > 0) {
            ref['main_subent_type'] = br.bl();
            ref['main_gsmarker'] = br.bl();
            final numPaths = br.bl();
            if (numPaths < 0 || numPaths > 10000) return null;
            ref['num_xrefpaths'] = numPaths;
            // the reference decoder's FIELD_VECTOR_T reads the T strings from the data
            // stream rather than the string stream; match it.
            final paths = <String>[];
            for (var i = 0; i < numPaths; i++) {
              final path = _inlineTu(br);
              if (path == null) return null;
              paths.add(path);
            }
            ref['xrefpaths'] = paths;
          }
          ref['osnap_dist'] = br.bd();
          ref['osnap_pt'] = [br.bd(), br.bd(), br.bd()];
          var numIntsectObject = 0;
          if (osnapType == 6 || osnapType == 11) {
            numIntsectObject = br.bl();
            if (numIntsectObject < 0 || numIntsectObject > 10000) return null;
            ref['num_intsectobj'] = numIntsectObject;
            ref['intersec_subent_type'] = br.bl();
            ref['intersec_gsmarker'] = br.bl();
            final numPaths = br.bl();
            if (numPaths < 0 || numPaths > 10000) return null;
            ref['num_intersec_xrefpaths'] = numPaths;
            final paths = <String>[];
            for (var i = 0; i < numPaths; i++) {
              final path = _inlineTu(br);
              if (path == null) return null;
              paths.add(path);
            }
            ref['intersec_xrefpaths'] = paths;
          }
          final hasLast = br.b();
          ref['has_lastpt_ref'] = hasLast;
          refs.add(ref);
          refInfo.add((
            numXrefs: numXrefs,
            numIntsectObject: numIntsectObject,
            ref: ref,
          ));
        }
        if (!br.ok) return null;
        final h = openHandles();
        final dimAssocValues = <String, Object?>{
          'associativity': associativity,
          'trans_space_flag': transSpaceFlag,
          'rotated_type': rotatedType,
          'ref': refs,
        };
        if (h != null) {
          dimAssocValues['dimensionobj'] = _handleOf(h, handle);
          for (final info in refInfo) {
            final xrefs = <int>[
              for (var i = 0; i < info.numXrefs; i++) _handleOf(h, handle),
            ];
            info.ref['xrefs'] = xrefs;
            if (info.numIntsectObject > 0) {
              info.ref['intsectobj'] = [
                for (var i = 0; i < info.numIntsectObject; i++)
                  _handleOf(h, handle),
              ];
            }
          }
        }
        values = dimAssocValues;
      case 'MATERIAL':
        final name = _text(br);
        final description = _text(br);
        if (!_printable(name)) return null;
        final material = <String, Object?>{};
        _readMaterialColor(br, 'ambient_color', material);
        _readMaterialColor(br, 'diffuse_color', material);
        _readMaterialMap(br, 'diffusemap', material, 0);
        _readMaterialColor(br, 'specular_color', material);
        _readMaterialMap(br, 'specularmap', material, 0);
        material['specular_gloss_factor'] = br.bd();
        _readMaterialMap(br, 'reflectionmap', material, 0);
        material['opacity_percent'] = br.bd();
        _readMaterialMap(br, 'opacitymap', material, 0);
        _readMaterialMap(br, 'bumpmap', material, 0);
        material['refraction_index'] = br.bd();
        _readMaterialMap(br, 'refractionmap', material, 0);
        if (_version >= 2007) {
          material['translucence'] = br.bd();
          material['self_illumination'] = br.bd();
          material['reflectivity'] = br.bd();
          material['illumination_model'] = br.bl();
          material['channel_flags'] = br.bl();
          material['mode'] = br.bl();
        }
        if (!br.ok) return null;
        values = {'name': name, 'description': description, ...material};
      case 'VISUALSTYLE':
        final description = _text(br);
        if (!_printable(description)) return null;
        final styleType = br.bl();
        final valuesMap = <String, Object?>{
          'description': description,
          'style_type': styleType,
        };
        if (_version < 2010) {
          valuesMap['face_lighting_model'] = br.bl();
          valuesMap['face_lighting_quality'] = br.bl();
          valuesMap['face_color_mode'] = br.bl();
          valuesMap['face_opacity'] = br.bd();
          valuesMap['face_specular'] = br.bd();
          valuesMap['face_mono_color'] = _readObjectCmc(br);
          valuesMap['face_modifier'] = br.bl();
          valuesMap['edge_model'] = br.bl();
          valuesMap['edge_style'] = br.bl();
          valuesMap['edge_intersection_color'] = _readObjectCmc(br);
          valuesMap['edge_obscured_color'] = _readObjectCmc(br);
          valuesMap['edge_obscured_ltype'] = _signedLong(br.bl());
          valuesMap['edge_crease_angle'] = br.bd();
          valuesMap['edge_modifier'] = br.bl();
          valuesMap['edge_color'] = _readObjectCmc(br);
          valuesMap['edge_opacity'] = br.bd();
          valuesMap['edge_width'] = br.bs();
          valuesMap['edge_overhang'] = br.bs();
          valuesMap['edge_jitter'] = br.bl();
          valuesMap['edge_silhouette_color'] = _readObjectCmc(br);
          valuesMap['edge_silhouette_width'] = br.bs();
          valuesMap['edge_halo_gap'] = br.rc();
          valuesMap['edge_isolines'] = br.bs();
          valuesMap['edge_do_hide_precision'] = br.b();
          valuesMap['edge_style_apply'] = br.bs();
          valuesMap['edge_intersection_ltype'] = br.bs();
          valuesMap['display_settings'] = br.bl();
          valuesMap['display_brightness_bl'] = _signedLong(br.bl());
          if (objectStartBit + bitsize - br.bitPos >= 3) {
            valuesMap['display_shadow_type'] = br.bl();
            if (_version >= 2007) valuesMap['bd2007_45'] = br.bd();
            valuesMap['internal_only'] = br.b();
          }
        } else {
          valuesMap['ext_lighting_model'] = br.bs();
          valuesMap['internal_only'] = br.b();
          void pair(String key, Object? Function() read) {
            valuesMap[key] = read();
            valuesMap['${key}_int'] = br.bs();
          }

          pair('face_lighting_model', br.bl);
          pair('face_lighting_quality', br.bl);
          pair('face_color_mode', br.bl);
          pair('face_modifier', br.bs);
          pair('face_opacity', br.bd);
          pair('face_specular', br.bd);
          pair('face_mono_color', () => _readObjectCmc(br));
          pair('edge_model', br.bl);
          pair('edge_style', br.bl);
          pair('edge_intersection_color', () => _readObjectCmc(br));
          pair('edge_obscured_color', () => _readObjectCmc(br));
          pair('edge_obscured_ltype', br.bl);
          pair('edge_intersection_ltype', br.bl);
          pair('edge_crease_angle', br.bd);
          pair('edge_modifier', br.bl);
          pair('edge_color', () => _readObjectCmc(br));
          pair('edge_opacity', br.bd);
          pair('edge_width', br.bl);
          pair('edge_overhang', br.bl);
          pair('edge_jitter', br.bl);
          pair('edge_silhouette_color', () => _readObjectCmc(br));
          pair('edge_silhouette_width', br.bl);
          pair('edge_halo_gap', br.bl);
          pair('edge_isolines', br.bl);
          pair('edge_do_hide_precision', br.b);
          pair('display_settings', br.bl);
          pair('display_brightness', br.bd);
          pair('display_shadow_type', br.bl);
          if (_version >= 2013) {
            pair('b_prop1c', br.b);
            pair('b_prop1d', br.b);
            pair('b_prop1e', br.b);
            pair('b_prop1f', br.b);
            pair('b_prop20', br.b);
            pair('b_prop21', br.b);
            pair('b_prop22', br.b);
            pair('b_prop23', br.b);
            pair('b_prop24', br.b);
            pair('bl_prop25', br.bl);
            pair('bd_prop26', br.bd);
            pair('bd_prop27', br.bd);
            pair('bl_prop28', br.bl);
            pair('c_prop29', () => _readObjectCmc(br));
            pair('bl_prop2a', br.bl);
            pair('bl_prop2b', br.bl);
            pair('c_prop2c', () => _readObjectCmc(br));
            pair('b_prop2d', br.b);
            pair('bl_prop2e', br.bl);
            pair('bl_prop2f', br.bl);
            pair('bl_prop30', br.bl);
            pair('b_prop31', br.b);
            pair('bl_prop32', br.bl);
            pair('c_prop33', () => _readObjectCmc(br));
            pair('bd_prop34', br.bd);
            pair('edge_wiggle', br.bl);
            pair('strokes', () => _text(br));
            pair('b_prop37', br.b);
            pair('bd_prop38', br.bd);
            pair('bd_prop39', br.bd);
          }
        }
        if (!br.ok) return null;
        values = valuesMap;
      case 'MTEXTOBJECTCONTEXTDATA':
        final classVersion = br.bs();
        final isDefault = br.b();
        final attachment = br.bl();
        final xAxis = [br.bd(), br.bd(), br.bd()];
        final insPt = [br.bd(), br.bd(), br.bd()];
        final rectWidth = br.bd();
        final rectHeight = br.bd();
        final extentsWidth = br.bd();
        final extentsHeight = br.bd();
        final columnType = br.bl();
        var columnWidth = 0.0;
        var gutter = 0.0;
        var autoHeight = 0;
        var flowReversed = 0;
        var numColumnHeights = 0;
        final columnHeights = <double>[];
        if (columnType != 0) {
          numColumnHeights = br.bl();
          columnWidth = br.bd();
          gutter = br.bd();
          autoHeight = br.b();
          flowReversed = br.b();
          if (autoHeight == 0 && columnType == 2) {
            if (numColumnHeights < 0 || numColumnHeights > 100000) return null;
            for (var i = 0; i < numColumnHeights; i++) {
              columnHeights.add(br.bd());
            }
          }
        }
        if (!br.ok) return null;
        final h = openHandles();
        values = {
          'class_version': classVersion,
          'is_default': isDefault,
          'attachment': attachment,
          'x_axis_dir': xAxis,
          'ins_pt': insPt,
          'rect_width': rectWidth,
          'rect_height': rectHeight,
          'extents_width': extentsWidth,
          'extents_height': extentsHeight,
          'column_type': columnType,
          'num_column_heights': numColumnHeights,
          'column_width': columnWidth,
          'gutter': gutter,
          'auto_height': autoHeight,
          'flow_reversed': flowReversed,
          'column_heights': columnHeights,
        };
        if (h != null) values['scale'] = _handleOf(h, handle);
      case 'GROUP':
        final name = _text(br);
        if (!_printable(name)) return null;
        final unnamed = br.bs();
        final selectable = br.bs();
        final count = br.bl();
        if (count < 0 || count > 10000) return null;
        final h = count > 0 ? openHandles() : null;
        final members = <int>[];
        if (h != null) {
          for (var i = 0; i < count; i++) {
            members.add(_handleOf(h, handle));
          }
        }
        values = {
          'name': name,
          'unnamed': unnamed,
          'selectable': selectable,
          'groups': members,
        };
      default:
        return null;
    }
    if (!br.ok) return null;
    return DwgObject(
      handle: handle,
      type: type,
      typeName: typeName,
      values: values,
    );
  }

  String? _inlineTu(DwgBitReader br) {
    final length = br.bs();
    if (!br.ok || length < 0 || length > 1000000) return null;
    final limit = br.limitBits ?? br.bitPos;
    if (length * 16 > limit - br.bitPos) return null;
    final units = <int>[];
    for (var i = 0; i < length; i++) {
      units.add(br.rs());
    }
    final text = String.fromCharCodes(units);
    return _printable(text) ? text : null;
  }

  void _readMaterialColor(
    DwgBitReader br,
    String prefix,
    Map<String, Object?> values,
  ) {
    final flag = br.rc();
    values['$prefix.flag'] = flag;
    values['$prefix.factor'] = br.bd();
    if (flag == 1) values['$prefix.rgb'] = br.bl();
  }

  void _readMaterialMap(
    DwgBitReader br,
    String prefix,
    Map<String, Object?> values,
    int depth,
  ) {
    values['$prefix.blendfactor'] = br.bd();
    values['$prefix.projection'] = br.rc();
    values['$prefix.tiling'] = br.rc();
    values['$prefix.autotransform'] = br.rc();
    values['$prefix.transmatrix'] = [for (var i = 0; i < 16; i++) br.bd()];
    final source = br.rc();
    values['$prefix.source'] = source;
    if (source == 1) {
      values['$prefix.filename'] = _text(br);
    } else if (source == 2) {
      _readMaterialTexture(br, prefix, values, depth + 1);
    }
  }

  void _readMaterialTexture(
    DwgBitReader br,
    String prefix,
    Map<String, Object?> values,
    int depth,
  ) {
    if (depth > 16) return;
    final mode = br.bs();
    values['$prefix.texturemode'] = mode;
    if (mode == 0) {
      _readMaterialColor(br, '$prefix.color1', values);
      _readMaterialColor(br, '$prefix.color2', values);
    } else if (mode == 1) {
      _readMaterialColor(br, '$prefix.color1', values);
      _readMaterialColor(br, '$prefix.color2', values);
    } else if (mode == 2) {
      final proc = br.bs();
      values['$prefix.genproctype'] = proc;
      switch (proc) {
        case 1:
          values['$prefix.genprocvalbool'] = br.b();
        case 2:
          values['$prefix.genprocvalint'] = br.bs();
        case 3:
          values['$prefix.genprocvalreal'] = br.bd();
        case 4:
          values['$prefix.genprocvalcolor'] = _readObjectCmc(br);
        case 5:
          values['$prefix.genprocvaltext'] = _text(br);
        case 6:
          final count = br.bs();
          if (count < 0 || count > 1000) return;
          for (var i = 0; i < count; i++) {
            final item = '$prefix.gentextures[$i]';
            values['$item.genprocname'] = _text(br);
            _readMaterialTexture(br, item, values, depth + 1);
          }
          values['$prefix.genproctableend'] = br.b();
        default:
          break;
      }
    }
  }

  static const _hexDigits = '0123456789ABCDEF';

  String _hexString(Uint8List bytes) {
    final out = Uint8List(bytes.length * 2);
    for (var i = 0; i < bytes.length; i++) {
      final byte = bytes[i];
      out[i * 2] = _hexDigits.codeUnitAt(byte >> 4);
      out[i * 2 + 1] = _hexDigits.codeUnitAt(byte & 0x0f);
    }
    return String.fromCharCodes(out);
  }

  List<List<Object?>>? _readXrecordXdata(DwgBitReader br, int xdataSize) {
    if (xdataSize < 0 || xdataSize > 1 << 24) return null;
    final start = br.bitPos;
    final end = start + xdataSize * 8;
    final items = <List<Object?>>[];
    var guard = 0;
    xdata:
    while (br.bitPos < end && br.ok && guard++ < 1000000) {
      final type = br.rs();
      final kind = _resbufType(type);
      final before = br.bitPos;
      Object? value;
      if (kind == 1) {
        if (_version >= 2007) {
          final length = br.rs();
          if (length < 0 || br.bitPos + length * 16 > end) break xdata;
          final raw = br.readBytes(length * 2);
          if (!br.ok) break xdata;
          final units = Uint16List(length);
          for (var i = 0; i < length; i++) {
            units[i] = raw[i * 2] | (raw[i * 2 + 1] << 8);
          }
          value = expandDwgTextEscapes(String.fromCharCodes(units));
        } else {
          final length = br.rs();
          if (length < 0 || length > 0xffff) break xdata;
          br.rc(); // codepage
          if (br.bitPos + length * 8 > end) break xdata;
          final raw = br.readBytes(length);
          if (!br.ok) break xdata;
          final nul = raw.indexOf(0);
          final text = nul < 0 ? raw : Uint8List.sublistView(raw, 0, nul);
          value = expandDwgTextEscapes(br.decodeCodepage(text));
        }
      } else if (kind == 2) {
        if (br.bitPos + 192 > end) break xdata;
        value = [br.rd(), br.rd(), br.rd()];
      } else if (kind == 3) {
        if (br.bitPos + 64 > end) break xdata;
        value = br.rd();
      } else if (kind == 4) {
        if (br.bitPos + 16 > end) break xdata;
        value = _signedShort(br.rs());
      } else if (kind == 5) {
        if (br.bitPos + 32 > end) break xdata;
        value = _signedLong(br.rl());
      } else if (kind == 6) {
        if (br.bitPos + 8 > end) break xdata;
        value = br.rc();
      } else if (kind == 7) {
        final size = br.rc();
        if (br.bitPos + size * 8 > end) break xdata;
        final raw = br.readBytes(size);
        if (!br.ok) break xdata;
        value = _hexString(raw);
      } else if (kind == 8 || kind == 9) {
        if (br.bitPos + 64 > end) break xdata;
        final raw = br.readBytes(8);
        if (!br.ok) break xdata;
        var handle = 0;
        for (var i = 0; i < 8; i++) {
          handle |= raw[i] << (i * 8);
        }
        value = handle;
      } else {
        break xdata;
      }
      if (!br.ok || br.bitPos == before) break xdata;
      items.add([type, value]);
    }
    if (br.bitPos < end) {
      // Keep the object census but do not expose a partial list.
      br.bitPos = end;
    }
    return items;
  }

  void _readHistoryNode(
    DwgBitReader br,
    Map<String, Object?> values,
    List<void Function(int)> pending,
  ) {
    values['history_node.major'] = br.bl();
    values['history_node.minor'] = br.bl();
    values['history_node.trans'] = [for (var i = 0; i < 16; i++) br.bd()];
    values['history_node.color'] = _readObjectCmc(br);
    values['history_node.step_id'] = br.bl();
    pending.add((h) => values['history_node.material'] = h);
  }

  void _readEvalExprFields(
    DwgBitReader br,
    String prefix,
    Map<String, Object?> values,
    List<void Function(int)> pending,
  ) {
    values['${prefix}parentid'] = _signedLong(br.bl());
    values['${prefix}major'] = br.bl();
    values['${prefix}minor'] = br.bl();
    final code = _signedShort(br.bs());
    values['${prefix}value_code'] = code;
    if (code != 0 && code != -9999) {
      switch (_resbufType(code)) {
        case 3:
          values['${prefix}value.num40'] = br.bd();
        case 10:
          values['${prefix}value.pt2d'] = [br.rd(), br.rd()];
        case 11:
          values['${prefix}value.pt3d'] = [br.rd(), br.rd()];
        case 1:
          values['${prefix}value.text1'] = _text(br);
        case 5:
          values['${prefix}value.long90'] = br.bl();
        case 8:
        case 9:
          pending.add((h) => values['${prefix}value.handle91'] = h);
        case 4:
          values['${prefix}value.short70'] = br.bs();
        default:
          break;
      }
    }
    values['${prefix}nodeid'] = br.bl();
  }

  void _readRenderSettings(DwgBitReader br, Map<String, Object?> values) {
    values['class_version'] = br.bl();
    values['name'] = _text(br);
    values['fog_enabled'] = br.b();
    values['fog_background_enabled'] = br.b();
    values['backfaces_enabled'] = br.b();
    values['environ_image_enabled'] = br.b();
    values['environ_image_filename'] = _text(br);
    values['description'] = _text(br);
    values['display_index'] = br.bl();
  }

  void _readAssocAction(
    DwgBitReader br,
    Map<String, Object?> values,
    List<void Function(int)> pending,
  ) {
    final classVersion = br.bs();
    values['class_version'] = classVersion;
    values['geometry_status'] = br.bl();
    pending.add((h) => values['owningnetwork'] = h);
    pending.add((h) => values['actionbody'] = h);
    values['action_index'] = br.bl();
    values['max_assoc_dep_index'] = br.bl();
    final numDeps = br.bl();
    if (numDeps < 0 || numDeps > 100000) return;
    final deps = <Map<String, Object?>>[];
    for (var i = 0; i < numDeps; i++) {
      final dep = <String, Object?>{'is_owned': br.b()};
      pending.add((h) => dep['dep'] = h);
      deps.add(dep);
    }
    values['deps'] = deps;
    if (classVersion > 1) {
      br.bs(); // DXF-only value written to the DWG stream as zero
      final numParams = br.bl();
      if (numParams < 0 || numParams > 100000) return;
      final ownedParams = <int>[];
      for (var i = 0; i < numParams; i++) {
        pending.add((h) => ownedParams.add(h));
      }
      values['owned_params'] = ownedParams;
      br.bs(); // DXF-only value written to the DWG stream as zero
      final numValues = br.bl();
      if (numValues < 0 || numValues > 100000) return;
      final params = <Map<String, Object?>>[];
      for (var i = 0; i < numValues; i++) {
        final param = <String, Object?>{};
        param['class_version'] = br.bl();
        param['name'] = _text(br);
        param['unit_type'] = br.bl();
        final numVars = br.bl();
        if (numVars < 0 || numVars > 100000) return;
        final vars = <Map<String, Object?>>[];
        for (var j = 0; j < numVars; j++) {
          final variable = <String, Object?>{};
          _readAssocVariant(br, variable, '', pending);
          pending.add((h) => variable['handle'] = h);
          vars.add(variable);
        }
        param['vars'] = vars;
        pending.add((h) => param['controlled_objdep'] = h);
        params.add(param);
      }
      values['values'] = params;
    }
  }

  void _readAssocVariant(
    DwgBitReader br,
    Map<String, Object?> values,
    String prefix,
    List<void Function(int)> pending,
  ) {
    final code = _signedShort(br.bs());
    values['${prefix}code'] = code;
    if (code == 0) return;
    switch (_resbufType(code)) {
      case 3:
        values['${prefix}u.bd'] = br.bd();
      case 5:
        values['${prefix}u.bl'] = br.bl();
      case 4:
        values['${prefix}u.bs'] = br.bs();
      case 6:
        values['${prefix}u.rc'] = br.rc();
      case 1:
        values['${prefix}u.text'] = _text(br);
      case 8:
      case 9:
        pending.add((h) => values['${prefix}u.handle'] = h);
      default:
        break;
    }
  }

  Map<String, Object?> _readObjectCmtc(DwgBitReader br) {
    final index = br.bs();
    final rgb = br.bl();
    final flag = br.rc();
    final color = <String, Object?>{
      'index': index > 0 && index < 256 ? index : aciIndexForRgb(rgb),
      'rgb': rgb.toRadixString(16).padLeft(8, '0'),
    };
    if (flag < 4) {
      if ((flag & 1) != 0) _text(br);
      if ((flag & 2) != 0) _text(br);
    }
    return color;
  }

  void _readCellStyle(
    DwgBitReader br,
    String prefix,
    Map<String, Object?> values,
    List<void Function(int)> pending,
  ) {
    values['$prefix.type'] = br.bl();
    final dataFlags = br.bs();
    values['$prefix.data_flags'] = dataFlags;
    if (dataFlags == 0) return;
    values['$prefix.property_override_flags'] = br.bl();
    values['$prefix.merge_flags'] = br.bl();
    values['$prefix.bg_color'] = _readObjectCmtc(br);
    values['$prefix.content_layout'] = br.bl();
    values['$prefix.content_format.property_override_flags'] = br.bl();
    values['$prefix.content_format.property_flags'] = br.bl();
    values['$prefix.content_format.value_data_type'] = br.bl();
    values['$prefix.content_format.value_unit_type'] = br.bl();
    values['$prefix.content_format.value_format_string'] = _text(br);
    values['$prefix.content_format.rotation'] = br.bd();
    values['$prefix.content_format.block_scale'] = br.bd();
    values['$prefix.content_format.cell_alignment'] = br.bl();
    values['$prefix.content_format.content_color'] = _readObjectCmtc(br);
    pending.add(
      (handle) => values['$prefix.content_format.text_style'] = handle,
    );
    values['$prefix.content_format.text_height'] = br.bd();
    final marginFlags = br.bs();
    values['$prefix.margin_override_flags'] = marginFlags;
    if (marginFlags != 0) {
      values['$prefix.vert_margin'] = br.bd();
      values['$prefix.horiz_margin'] = br.bd();
      values['$prefix.bottom_margin'] = br.bd();
      values['$prefix.right_margin'] = br.bd();
      values['$prefix.margin_horiz_spacing'] = br.bd();
      values['$prefix.margin_vert_spacing'] = br.bd();
    }
    final numBorders = br.bl();
    values['$prefix.num_borders'] = numBorders;
    if (numBorders < 0 || numBorders > 6) return;
    final borders = <Map<String, Object?>>[];
    for (var i = 0; i < numBorders; i++) {
      final border = <String, Object?>{};
      final mask = br.bl();
      border['index_mask'] = mask;
      if (mask != 0) {
        border['border_overrides'] = br.bl();
        border['border_type'] = br.bl();
        border['color'] = _readObjectCmtc(br);
        border['linewt'] = _signedLong(br.bl());
        pending.add((handle) => border['ltype'] = handle);
        border['visible'] = br.bl();
        border['double_line_spacing'] = br.bd();
      }
      borders.add(border);
    }
    values['$prefix.borders'] = borders;
  }

  Map<String, Object?> _readObjectCmc(DwgBitReader br) {
    var index = br.bs();
    final color = <String, Object?>{'index': index};
    if (_version >= 2004) {
      final rgb = br.bl();
      final flag = br.rc();
      color['rgb'] = rgb.toRadixString(16).padLeft(8, '0');
      if (flag < 4) {
        if ((flag & 1) != 0) _text(br);
        if ((flag & 2) != 0) _text(br);
      }
      // the reference decoder replaces a sentinel index with the palette entry that
      // matches the true colour, so decoded values agree with its output.
      if (index <= 0 || index >= 256) {
        index = aciIndexForRgb(rgb);
        color['index'] = index;
      }
    }
    return color;
  }

  int _signedShort(int value) => value >= 0x8000 ? value - 0x10000 : value;

  int _signedLong(int value) =>
      value >= 0x80000000 ? value - 0x100000000 : value;

  /// the reference decoder's dwg_resbuf_value_type mapping, reduced to the categories the
  /// XRECORD decoder cares about.
  int _resbufType(int code) {
    if (code >= 300) {
      if (code >= 440) {
        if (code >= 1000) {
          if (code == 1004) return 7;
          if (code <= 1009) return 1;
          if (code <= 1039) return 2;
          if (code <= 1042) return 3;
          if (code <= 1069) return 2;
          if (code <= 1070) return 4;
          if (code == 1071) return 5;
        } else {
          if (code <= 459) return 5;
          if (code <= 469) return 3;
          if (code <= 479) return 1;
          if (code == 999) return 1;
        }
      } else {
        if (code >= 390) {
          if (code <= 399) return 8;
          if (code <= 409) return 4;
          if (code <= 419) return 1;
          if (code <= 429) return 5;
          if (code <= 439) return 1;
        } else {
          if (code <= 309) return 1;
          if (code <= 319) return 7;
          if (code <= 329) return 8;
          if (code <= 369) return 9;
          if (code <= 389) return 4;
        }
      }
    } else if (code >= 105) {
      if (code >= 210) {
        if (code <= 269) return 2;
        if (code <= 279) return 4;
        if (code <= 289) return 6;
        if (code <= 299) return 6;
      } else {
        if (code == 105) return 8;
        if (code <= 109) return 0;
        if (code <= 139) return 2;
        if (code <= 149) return 3;
        if (code <= 169) return 11;
        if (code <= 179) return 4;
        if (code <= 209) return 0;
      }
    } else {
      if (code >= 38) {
        if (code <= 59) return 3;
        if (code <= 79) return 4;
        if (code <= 99) return 5;
        if (code <= 102) return 1;
      } else {
        if (code < 0) return 8;
        if (code <= 4) return 1;
        if (code == 5) return 8;
        if (code <= 9) return 1;
        if (code <= 37) return 2;
      }
    }
    return 0;
  }
}
