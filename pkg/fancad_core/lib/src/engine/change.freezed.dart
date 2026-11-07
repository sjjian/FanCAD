// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'change.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DocumentChange {

 List<int> get added; List<int> get removed; List<int> get modified;/// A symbol table (layers, line types, styles) changed, so resolved styles
/// must be recomputed even for untouched entities.
 bool get tablesChanged;/// Blocks or layouts changed, so any cached block geometry is stale.
 bool get structureChanged;
/// Create a copy of DocumentChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentChangeCopyWith<DocumentChange> get copyWith => _$DocumentChangeCopyWithImpl<DocumentChange>(this as DocumentChange, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentChange&&const DeepCollectionEquality().equals(other.added, added)&&const DeepCollectionEquality().equals(other.removed, removed)&&const DeepCollectionEquality().equals(other.modified, modified)&&(identical(other.tablesChanged, tablesChanged) || other.tablesChanged == tablesChanged)&&(identical(other.structureChanged, structureChanged) || other.structureChanged == structureChanged));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(added),const DeepCollectionEquality().hash(removed),const DeepCollectionEquality().hash(modified),tablesChanged,structureChanged);



}

/// @nodoc
abstract mixin class $DocumentChangeCopyWith<$Res>  {
  factory $DocumentChangeCopyWith(DocumentChange value, $Res Function(DocumentChange) _then) = _$DocumentChangeCopyWithImpl;
@useResult
$Res call({
 List<int> added, List<int> removed, List<int> modified, bool tablesChanged, bool structureChanged
});




}
/// @nodoc
class _$DocumentChangeCopyWithImpl<$Res>
    implements $DocumentChangeCopyWith<$Res> {
  _$DocumentChangeCopyWithImpl(this._self, this._then);

  final DocumentChange _self;
  final $Res Function(DocumentChange) _then;

/// Create a copy of DocumentChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? added = null,Object? removed = null,Object? modified = null,Object? tablesChanged = null,Object? structureChanged = null,}) {
  return _then(_self.copyWith(
added: null == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as List<int>,removed: null == removed ? _self.removed : removed // ignore: cast_nullable_to_non_nullable
as List<int>,modified: null == modified ? _self.modified : modified // ignore: cast_nullable_to_non_nullable
as List<int>,tablesChanged: null == tablesChanged ? _self.tablesChanged : tablesChanged // ignore: cast_nullable_to_non_nullable
as bool,structureChanged: null == structureChanged ? _self.structureChanged : structureChanged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentChange].
extension DocumentChangePatterns on DocumentChange {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentChange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentChange() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentChange value)  $default,){
final _that = this;
switch (_that) {
case _DocumentChange():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentChange value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentChange() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<int> added,  List<int> removed,  List<int> modified,  bool tablesChanged,  bool structureChanged)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentChange() when $default != null:
return $default(_that.added,_that.removed,_that.modified,_that.tablesChanged,_that.structureChanged);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<int> added,  List<int> removed,  List<int> modified,  bool tablesChanged,  bool structureChanged)  $default,) {final _that = this;
switch (_that) {
case _DocumentChange():
return $default(_that.added,_that.removed,_that.modified,_that.tablesChanged,_that.structureChanged);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<int> added,  List<int> removed,  List<int> modified,  bool tablesChanged,  bool structureChanged)?  $default,) {final _that = this;
switch (_that) {
case _DocumentChange() when $default != null:
return $default(_that.added,_that.removed,_that.modified,_that.tablesChanged,_that.structureChanged);case _:
  return null;

}
}

}

/// @nodoc


class _DocumentChange extends DocumentChange {
  const _DocumentChange({final  List<int> added = const [], final  List<int> removed = const [], final  List<int> modified = const [], this.tablesChanged = false, this.structureChanged = false}): _added = added,_removed = removed,_modified = modified,super._();
  

 final  List<int> _added;
@override@JsonKey() List<int> get added {
  if (_added is EqualUnmodifiableListView) return _added;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_added);
}

 final  List<int> _removed;
@override@JsonKey() List<int> get removed {
  if (_removed is EqualUnmodifiableListView) return _removed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_removed);
}

 final  List<int> _modified;
@override@JsonKey() List<int> get modified {
  if (_modified is EqualUnmodifiableListView) return _modified;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modified);
}

/// A symbol table (layers, line types, styles) changed, so resolved styles
/// must be recomputed even for untouched entities.
@override@JsonKey() final  bool tablesChanged;
/// Blocks or layouts changed, so any cached block geometry is stale.
@override@JsonKey() final  bool structureChanged;

/// Create a copy of DocumentChange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentChangeCopyWith<_DocumentChange> get copyWith => __$DocumentChangeCopyWithImpl<_DocumentChange>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentChange&&const DeepCollectionEquality().equals(other._added, _added)&&const DeepCollectionEquality().equals(other._removed, _removed)&&const DeepCollectionEquality().equals(other._modified, _modified)&&(identical(other.tablesChanged, tablesChanged) || other.tablesChanged == tablesChanged)&&(identical(other.structureChanged, structureChanged) || other.structureChanged == structureChanged));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_added),const DeepCollectionEquality().hash(_removed),const DeepCollectionEquality().hash(_modified),tablesChanged,structureChanged);



}

/// @nodoc
abstract mixin class _$DocumentChangeCopyWith<$Res> implements $DocumentChangeCopyWith<$Res> {
  factory _$DocumentChangeCopyWith(_DocumentChange value, $Res Function(_DocumentChange) _then) = __$DocumentChangeCopyWithImpl;
@override @useResult
$Res call({
 List<int> added, List<int> removed, List<int> modified, bool tablesChanged, bool structureChanged
});




}
/// @nodoc
class __$DocumentChangeCopyWithImpl<$Res>
    implements _$DocumentChangeCopyWith<$Res> {
  __$DocumentChangeCopyWithImpl(this._self, this._then);

  final _DocumentChange _self;
  final $Res Function(_DocumentChange) _then;

/// Create a copy of DocumentChange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? added = null,Object? removed = null,Object? modified = null,Object? tablesChanged = null,Object? structureChanged = null,}) {
  return _then(_DocumentChange(
added: null == added ? _self._added : added // ignore: cast_nullable_to_non_nullable
as List<int>,removed: null == removed ? _self._removed : removed // ignore: cast_nullable_to_non_nullable
as List<int>,modified: null == modified ? _self._modified : modified // ignore: cast_nullable_to_non_nullable
as List<int>,tablesChanged: null == tablesChanged ? _self.tablesChanged : tablesChanged // ignore: cast_nullable_to_non_nullable
as bool,structureChanged: null == structureChanged ? _self.structureChanged : structureChanged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
