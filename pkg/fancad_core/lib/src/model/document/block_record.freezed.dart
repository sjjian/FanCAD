// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'block_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BlockRecord {

 String get name; Vec2 get basePoint; List<int> get entityIds;/// True for `*Model_Space` and `*Paper_Space*`, which are containers rather
/// than insertable blocks.
 bool get isLayoutBlock;/// True for generated blocks such as the `*D` dimension geometry blocks and
/// `*U` hatch blocks, which are hidden from the block picker.
 bool get isAnonymous; String get description;/// Non-empty when this block is an external reference.
 String get xrefPath;
/// Create a copy of BlockRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BlockRecordCopyWith<BlockRecord> get copyWith => _$BlockRecordCopyWithImpl<BlockRecord>(this as BlockRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BlockRecord&&(identical(other.name, name) || other.name == name)&&(identical(other.basePoint, basePoint) || other.basePoint == basePoint)&&const DeepCollectionEquality().equals(other.entityIds, entityIds)&&(identical(other.isLayoutBlock, isLayoutBlock) || other.isLayoutBlock == isLayoutBlock)&&(identical(other.isAnonymous, isAnonymous) || other.isAnonymous == isAnonymous)&&(identical(other.description, description) || other.description == description)&&(identical(other.xrefPath, xrefPath) || other.xrefPath == xrefPath));
}


@override
int get hashCode => Object.hash(runtimeType,name,basePoint,const DeepCollectionEquality().hash(entityIds),isLayoutBlock,isAnonymous,description,xrefPath);



}

/// @nodoc
abstract mixin class $BlockRecordCopyWith<$Res>  {
  factory $BlockRecordCopyWith(BlockRecord value, $Res Function(BlockRecord) _then) = _$BlockRecordCopyWithImpl;
@useResult
$Res call({
 String name, Vec2 basePoint, List<int> entityIds, bool isLayoutBlock, bool isAnonymous, String description, String xrefPath
});




}
/// @nodoc
class _$BlockRecordCopyWithImpl<$Res>
    implements $BlockRecordCopyWith<$Res> {
  _$BlockRecordCopyWithImpl(this._self, this._then);

  final BlockRecord _self;
  final $Res Function(BlockRecord) _then;

/// Create a copy of BlockRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? basePoint = null,Object? entityIds = null,Object? isLayoutBlock = null,Object? isAnonymous = null,Object? description = null,Object? xrefPath = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,basePoint: null == basePoint ? _self.basePoint : basePoint // ignore: cast_nullable_to_non_nullable
as Vec2,entityIds: null == entityIds ? _self.entityIds : entityIds // ignore: cast_nullable_to_non_nullable
as List<int>,isLayoutBlock: null == isLayoutBlock ? _self.isLayoutBlock : isLayoutBlock // ignore: cast_nullable_to_non_nullable
as bool,isAnonymous: null == isAnonymous ? _self.isAnonymous : isAnonymous // ignore: cast_nullable_to_non_nullable
as bool,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,xrefPath: null == xrefPath ? _self.xrefPath : xrefPath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BlockRecord].
extension BlockRecordPatterns on BlockRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BlockRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BlockRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BlockRecord value)  $default,){
final _that = this;
switch (_that) {
case _BlockRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BlockRecord value)?  $default,){
final _that = this;
switch (_that) {
case _BlockRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  Vec2 basePoint,  List<int> entityIds,  bool isLayoutBlock,  bool isAnonymous,  String description,  String xrefPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BlockRecord() when $default != null:
return $default(_that.name,_that.basePoint,_that.entityIds,_that.isLayoutBlock,_that.isAnonymous,_that.description,_that.xrefPath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  Vec2 basePoint,  List<int> entityIds,  bool isLayoutBlock,  bool isAnonymous,  String description,  String xrefPath)  $default,) {final _that = this;
switch (_that) {
case _BlockRecord():
return $default(_that.name,_that.basePoint,_that.entityIds,_that.isLayoutBlock,_that.isAnonymous,_that.description,_that.xrefPath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  Vec2 basePoint,  List<int> entityIds,  bool isLayoutBlock,  bool isAnonymous,  String description,  String xrefPath)?  $default,) {final _that = this;
switch (_that) {
case _BlockRecord() when $default != null:
return $default(_that.name,_that.basePoint,_that.entityIds,_that.isLayoutBlock,_that.isAnonymous,_that.description,_that.xrefPath);case _:
  return null;

}
}

}

/// @nodoc


class _BlockRecord extends BlockRecord {
  const _BlockRecord({required this.name, this.basePoint = const Vec2.zero(), final  List<int> entityIds = const [], this.isLayoutBlock = false, this.isAnonymous = false, this.description = '', this.xrefPath = ''}): _entityIds = entityIds,super._();
  

@override final  String name;
@override@JsonKey() final  Vec2 basePoint;
 final  List<int> _entityIds;
@override@JsonKey() List<int> get entityIds {
  if (_entityIds is EqualUnmodifiableListView) return _entityIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entityIds);
}

/// True for `*Model_Space` and `*Paper_Space*`, which are containers rather
/// than insertable blocks.
@override@JsonKey() final  bool isLayoutBlock;
/// True for generated blocks such as the `*D` dimension geometry blocks and
/// `*U` hatch blocks, which are hidden from the block picker.
@override@JsonKey() final  bool isAnonymous;
@override@JsonKey() final  String description;
/// Non-empty when this block is an external reference.
@override@JsonKey() final  String xrefPath;

/// Create a copy of BlockRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BlockRecordCopyWith<_BlockRecord> get copyWith => __$BlockRecordCopyWithImpl<_BlockRecord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BlockRecord&&(identical(other.name, name) || other.name == name)&&(identical(other.basePoint, basePoint) || other.basePoint == basePoint)&&const DeepCollectionEquality().equals(other._entityIds, _entityIds)&&(identical(other.isLayoutBlock, isLayoutBlock) || other.isLayoutBlock == isLayoutBlock)&&(identical(other.isAnonymous, isAnonymous) || other.isAnonymous == isAnonymous)&&(identical(other.description, description) || other.description == description)&&(identical(other.xrefPath, xrefPath) || other.xrefPath == xrefPath));
}


@override
int get hashCode => Object.hash(runtimeType,name,basePoint,const DeepCollectionEquality().hash(_entityIds),isLayoutBlock,isAnonymous,description,xrefPath);



}

/// @nodoc
abstract mixin class _$BlockRecordCopyWith<$Res> implements $BlockRecordCopyWith<$Res> {
  factory _$BlockRecordCopyWith(_BlockRecord value, $Res Function(_BlockRecord) _then) = __$BlockRecordCopyWithImpl;
@override @useResult
$Res call({
 String name, Vec2 basePoint, List<int> entityIds, bool isLayoutBlock, bool isAnonymous, String description, String xrefPath
});




}
/// @nodoc
class __$BlockRecordCopyWithImpl<$Res>
    implements _$BlockRecordCopyWith<$Res> {
  __$BlockRecordCopyWithImpl(this._self, this._then);

  final _BlockRecord _self;
  final $Res Function(_BlockRecord) _then;

/// Create a copy of BlockRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? basePoint = null,Object? entityIds = null,Object? isLayoutBlock = null,Object? isAnonymous = null,Object? description = null,Object? xrefPath = null,}) {
  return _then(_BlockRecord(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,basePoint: null == basePoint ? _self.basePoint : basePoint // ignore: cast_nullable_to_non_nullable
as Vec2,entityIds: null == entityIds ? _self._entityIds : entityIds // ignore: cast_nullable_to_non_nullable
as List<int>,isLayoutBlock: null == isLayoutBlock ? _self.isLayoutBlock : isLayoutBlock // ignore: cast_nullable_to_non_nullable
as bool,isAnonymous: null == isAnonymous ? _self.isAnonymous : isAnonymous // ignore: cast_nullable_to_non_nullable
as bool,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,xrefPath: null == xrefPath ? _self.xrefPath : xrefPath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
