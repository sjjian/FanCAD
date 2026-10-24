// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginEditorTargetModel {

 String get id; String get relative;
/// Create a copy of PluginEditorTargetModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginEditorTargetModelCopyWith<PluginEditorTargetModel> get copyWith => _$PluginEditorTargetModelCopyWithImpl<PluginEditorTargetModel>(this as PluginEditorTargetModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginEditorTargetModel&&(identical(other.id, id) || other.id == id)&&(identical(other.relative, relative) || other.relative == relative));
}


@override
int get hashCode => Object.hash(runtimeType,id,relative);

@override
String toString() {
  return 'PluginEditorTargetModel(id: $id, relative: $relative)';
}


}

/// @nodoc
abstract mixin class $PluginEditorTargetModelCopyWith<$Res>  {
  factory $PluginEditorTargetModelCopyWith(PluginEditorTargetModel value, $Res Function(PluginEditorTargetModel) _then) = _$PluginEditorTargetModelCopyWithImpl;
@useResult
$Res call({
 String id, String relative
});




}
/// @nodoc
class _$PluginEditorTargetModelCopyWithImpl<$Res>
    implements $PluginEditorTargetModelCopyWith<$Res> {
  _$PluginEditorTargetModelCopyWithImpl(this._self, this._then);

  final PluginEditorTargetModel _self;
  final $Res Function(PluginEditorTargetModel) _then;

/// Create a copy of PluginEditorTargetModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? relative = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,relative: null == relative ? _self.relative : relative // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginEditorTargetModel].
extension PluginEditorTargetModelPatterns on PluginEditorTargetModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginEditorTargetModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginEditorTargetModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginEditorTargetModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginEditorTargetModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginEditorTargetModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginEditorTargetModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String relative)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginEditorTargetModel() when $default != null:
return $default(_that.id,_that.relative);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String relative)  $default,) {final _that = this;
switch (_that) {
case _PluginEditorTargetModel():
return $default(_that.id,_that.relative);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String relative)?  $default,) {final _that = this;
switch (_that) {
case _PluginEditorTargetModel() when $default != null:
return $default(_that.id,_that.relative);case _:
  return null;

}
}

}

/// @nodoc


class _PluginEditorTargetModel implements PluginEditorTargetModel {
  const _PluginEditorTargetModel({required this.id, required this.relative});
  

@override final  String id;
@override final  String relative;

/// Create a copy of PluginEditorTargetModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginEditorTargetModelCopyWith<_PluginEditorTargetModel> get copyWith => __$PluginEditorTargetModelCopyWithImpl<_PluginEditorTargetModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginEditorTargetModel&&(identical(other.id, id) || other.id == id)&&(identical(other.relative, relative) || other.relative == relative));
}


@override
int get hashCode => Object.hash(runtimeType,id,relative);

@override
String toString() {
  return 'PluginEditorTargetModel(id: $id, relative: $relative)';
}


}

/// @nodoc
abstract mixin class _$PluginEditorTargetModelCopyWith<$Res> implements $PluginEditorTargetModelCopyWith<$Res> {
  factory _$PluginEditorTargetModelCopyWith(_PluginEditorTargetModel value, $Res Function(_PluginEditorTargetModel) _then) = __$PluginEditorTargetModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String relative
});




}
/// @nodoc
class __$PluginEditorTargetModelCopyWithImpl<$Res>
    implements _$PluginEditorTargetModelCopyWith<$Res> {
  __$PluginEditorTargetModelCopyWithImpl(this._self, this._then);

  final _PluginEditorTargetModel _self;
  final $Res Function(_PluginEditorTargetModel) _then;

/// Create a copy of PluginEditorTargetModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? relative = null,}) {
  return _then(_PluginEditorTargetModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,relative: null == relative ? _self.relative : relative // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PluginEditorModel {

 PluginEditorTargetModel? get target; int get request;
/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginEditorModelCopyWith<PluginEditorModel> get copyWith => _$PluginEditorModelCopyWithImpl<PluginEditorModel>(this as PluginEditorModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginEditorModel&&(identical(other.target, target) || other.target == target)&&(identical(other.request, request) || other.request == request));
}


@override
int get hashCode => Object.hash(runtimeType,target,request);

@override
String toString() {
  return 'PluginEditorModel(target: $target, request: $request)';
}


}

/// @nodoc
abstract mixin class $PluginEditorModelCopyWith<$Res>  {
  factory $PluginEditorModelCopyWith(PluginEditorModel value, $Res Function(PluginEditorModel) _then) = _$PluginEditorModelCopyWithImpl;
@useResult
$Res call({
 PluginEditorTargetModel? target, int request
});


$PluginEditorTargetModelCopyWith<$Res>? get target;

}
/// @nodoc
class _$PluginEditorModelCopyWithImpl<$Res>
    implements $PluginEditorModelCopyWith<$Res> {
  _$PluginEditorModelCopyWithImpl(this._self, this._then);

  final PluginEditorModel _self;
  final $Res Function(PluginEditorModel) _then;

/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = freezed,Object? request = null,}) {
  return _then(_self.copyWith(
target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as PluginEditorTargetModel?,request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginEditorTargetModelCopyWith<$Res>? get target {
    if (_self.target == null) {
    return null;
  }

  return $PluginEditorTargetModelCopyWith<$Res>(_self.target!, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}


/// Adds pattern-matching-related methods to [PluginEditorModel].
extension PluginEditorModelPatterns on PluginEditorModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginEditorModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginEditorModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginEditorModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginEditorModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginEditorModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginEditorModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PluginEditorTargetModel? target,  int request)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginEditorModel() when $default != null:
return $default(_that.target,_that.request);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PluginEditorTargetModel? target,  int request)  $default,) {final _that = this;
switch (_that) {
case _PluginEditorModel():
return $default(_that.target,_that.request);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PluginEditorTargetModel? target,  int request)?  $default,) {final _that = this;
switch (_that) {
case _PluginEditorModel() when $default != null:
return $default(_that.target,_that.request);case _:
  return null;

}
}

}

/// @nodoc


class _PluginEditorModel implements PluginEditorModel {
  const _PluginEditorModel({this.target, this.request = 0});
  

@override final  PluginEditorTargetModel? target;
@override@JsonKey() final  int request;

/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginEditorModelCopyWith<_PluginEditorModel> get copyWith => __$PluginEditorModelCopyWithImpl<_PluginEditorModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginEditorModel&&(identical(other.target, target) || other.target == target)&&(identical(other.request, request) || other.request == request));
}


@override
int get hashCode => Object.hash(runtimeType,target,request);

@override
String toString() {
  return 'PluginEditorModel(target: $target, request: $request)';
}


}

/// @nodoc
abstract mixin class _$PluginEditorModelCopyWith<$Res> implements $PluginEditorModelCopyWith<$Res> {
  factory _$PluginEditorModelCopyWith(_PluginEditorModel value, $Res Function(_PluginEditorModel) _then) = __$PluginEditorModelCopyWithImpl;
@override @useResult
$Res call({
 PluginEditorTargetModel? target, int request
});


@override $PluginEditorTargetModelCopyWith<$Res>? get target;

}
/// @nodoc
class __$PluginEditorModelCopyWithImpl<$Res>
    implements _$PluginEditorModelCopyWith<$Res> {
  __$PluginEditorModelCopyWithImpl(this._self, this._then);

  final _PluginEditorModel _self;
  final $Res Function(_PluginEditorModel) _then;

/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = freezed,Object? request = null,}) {
  return _then(_PluginEditorModel(
target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as PluginEditorTargetModel?,request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of PluginEditorModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginEditorTargetModelCopyWith<$Res>? get target {
    if (_self.target == null) {
    return null;
  }

  return $PluginEditorTargetModelCopyWith<$Res>(_self.target!, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}

/// @nodoc
mixin _$PluginPanelModel {

 String get id; String get pluginId; String get title; String get location; String get icon;
/// Create a copy of PluginPanelModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginPanelModelCopyWith<PluginPanelModel> get copyWith => _$PluginPanelModelCopyWithImpl<PluginPanelModel>(this as PluginPanelModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPanelModel&&(identical(other.id, id) || other.id == id)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.title, title) || other.title == title)&&(identical(other.location, location) || other.location == location)&&(identical(other.icon, icon) || other.icon == icon));
}


@override
int get hashCode => Object.hash(runtimeType,id,pluginId,title,location,icon);

@override
String toString() {
  return 'PluginPanelModel(id: $id, pluginId: $pluginId, title: $title, location: $location, icon: $icon)';
}


}

/// @nodoc
abstract mixin class $PluginPanelModelCopyWith<$Res>  {
  factory $PluginPanelModelCopyWith(PluginPanelModel value, $Res Function(PluginPanelModel) _then) = _$PluginPanelModelCopyWithImpl;
@useResult
$Res call({
 String id, String pluginId, String title, String location, String icon
});




}
/// @nodoc
class _$PluginPanelModelCopyWithImpl<$Res>
    implements $PluginPanelModelCopyWith<$Res> {
  _$PluginPanelModelCopyWithImpl(this._self, this._then);

  final PluginPanelModel _self;
  final $Res Function(PluginPanelModel) _then;

/// Create a copy of PluginPanelModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? pluginId = null,Object? title = null,Object? location = null,Object? icon = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginPanelModel].
extension PluginPanelModelPatterns on PluginPanelModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginPanelModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginPanelModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginPanelModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginPanelModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginPanelModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginPanelModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String pluginId,  String title,  String location,  String icon)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginPanelModel() when $default != null:
return $default(_that.id,_that.pluginId,_that.title,_that.location,_that.icon);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String pluginId,  String title,  String location,  String icon)  $default,) {final _that = this;
switch (_that) {
case _PluginPanelModel():
return $default(_that.id,_that.pluginId,_that.title,_that.location,_that.icon);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String pluginId,  String title,  String location,  String icon)?  $default,) {final _that = this;
switch (_that) {
case _PluginPanelModel() when $default != null:
return $default(_that.id,_that.pluginId,_that.title,_that.location,_that.icon);case _:
  return null;

}
}

}

/// @nodoc


class _PluginPanelModel implements PluginPanelModel {
  const _PluginPanelModel({required this.id, required this.pluginId, this.title = '', this.location = 'sidebar', this.icon = ''});
  

@override final  String id;
@override final  String pluginId;
@override@JsonKey() final  String title;
@override@JsonKey() final  String location;
@override@JsonKey() final  String icon;

/// Create a copy of PluginPanelModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginPanelModelCopyWith<_PluginPanelModel> get copyWith => __$PluginPanelModelCopyWithImpl<_PluginPanelModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginPanelModel&&(identical(other.id, id) || other.id == id)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.title, title) || other.title == title)&&(identical(other.location, location) || other.location == location)&&(identical(other.icon, icon) || other.icon == icon));
}


@override
int get hashCode => Object.hash(runtimeType,id,pluginId,title,location,icon);

@override
String toString() {
  return 'PluginPanelModel(id: $id, pluginId: $pluginId, title: $title, location: $location, icon: $icon)';
}


}

/// @nodoc
abstract mixin class _$PluginPanelModelCopyWith<$Res> implements $PluginPanelModelCopyWith<$Res> {
  factory _$PluginPanelModelCopyWith(_PluginPanelModel value, $Res Function(_PluginPanelModel) _then) = __$PluginPanelModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String pluginId, String title, String location, String icon
});




}
/// @nodoc
class __$PluginPanelModelCopyWithImpl<$Res>
    implements _$PluginPanelModelCopyWith<$Res> {
  __$PluginPanelModelCopyWithImpl(this._self, this._then);

  final _PluginPanelModel _self;
  final $Res Function(_PluginPanelModel) _then;

/// Create a copy of PluginPanelModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? pluginId = null,Object? title = null,Object? location = null,Object? icon = null,}) {
  return _then(_PluginPanelModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PluginDialogModel {

 int get token; String get pluginId; String get title; String get bodyJson; List<String> get buttons; bool get prompt;
/// Create a copy of PluginDialogModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginDialogModelCopyWith<PluginDialogModel> get copyWith => _$PluginDialogModelCopyWithImpl<PluginDialogModel>(this as PluginDialogModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginDialogModel&&(identical(other.token, token) || other.token == token)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.title, title) || other.title == title)&&(identical(other.bodyJson, bodyJson) || other.bodyJson == bodyJson)&&const DeepCollectionEquality().equals(other.buttons, buttons)&&(identical(other.prompt, prompt) || other.prompt == prompt));
}


@override
int get hashCode => Object.hash(runtimeType,token,pluginId,title,bodyJson,const DeepCollectionEquality().hash(buttons),prompt);

@override
String toString() {
  return 'PluginDialogModel(token: $token, pluginId: $pluginId, title: $title, bodyJson: $bodyJson, buttons: $buttons, prompt: $prompt)';
}


}

/// @nodoc
abstract mixin class $PluginDialogModelCopyWith<$Res>  {
  factory $PluginDialogModelCopyWith(PluginDialogModel value, $Res Function(PluginDialogModel) _then) = _$PluginDialogModelCopyWithImpl;
@useResult
$Res call({
 int token, String pluginId, String title, String bodyJson, List<String> buttons, bool prompt
});




}
/// @nodoc
class _$PluginDialogModelCopyWithImpl<$Res>
    implements $PluginDialogModelCopyWith<$Res> {
  _$PluginDialogModelCopyWithImpl(this._self, this._then);

  final PluginDialogModel _self;
  final $Res Function(PluginDialogModel) _then;

/// Create a copy of PluginDialogModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? pluginId = null,Object? title = null,Object? bodyJson = null,Object? buttons = null,Object? prompt = null,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,bodyJson: null == bodyJson ? _self.bodyJson : bodyJson // ignore: cast_nullable_to_non_nullable
as String,buttons: null == buttons ? _self.buttons : buttons // ignore: cast_nullable_to_non_nullable
as List<String>,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginDialogModel].
extension PluginDialogModelPatterns on PluginDialogModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginDialogModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginDialogModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginDialogModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginDialogModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginDialogModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginDialogModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int token,  String pluginId,  String title,  String bodyJson,  List<String> buttons,  bool prompt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginDialogModel() when $default != null:
return $default(_that.token,_that.pluginId,_that.title,_that.bodyJson,_that.buttons,_that.prompt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int token,  String pluginId,  String title,  String bodyJson,  List<String> buttons,  bool prompt)  $default,) {final _that = this;
switch (_that) {
case _PluginDialogModel():
return $default(_that.token,_that.pluginId,_that.title,_that.bodyJson,_that.buttons,_that.prompt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int token,  String pluginId,  String title,  String bodyJson,  List<String> buttons,  bool prompt)?  $default,) {final _that = this;
switch (_that) {
case _PluginDialogModel() when $default != null:
return $default(_that.token,_that.pluginId,_that.title,_that.bodyJson,_that.buttons,_that.prompt);case _:
  return null;

}
}

}

/// @nodoc


class _PluginDialogModel implements PluginDialogModel {
  const _PluginDialogModel({required this.token, required this.pluginId, this.title = '', this.bodyJson = '{}', final  List<String> buttons = const [], this.prompt = false}): _buttons = buttons;
  

@override final  int token;
@override final  String pluginId;
@override@JsonKey() final  String title;
@override@JsonKey() final  String bodyJson;
 final  List<String> _buttons;
@override@JsonKey() List<String> get buttons {
  if (_buttons is EqualUnmodifiableListView) return _buttons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_buttons);
}

@override@JsonKey() final  bool prompt;

/// Create a copy of PluginDialogModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginDialogModelCopyWith<_PluginDialogModel> get copyWith => __$PluginDialogModelCopyWithImpl<_PluginDialogModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginDialogModel&&(identical(other.token, token) || other.token == token)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.title, title) || other.title == title)&&(identical(other.bodyJson, bodyJson) || other.bodyJson == bodyJson)&&const DeepCollectionEquality().equals(other._buttons, _buttons)&&(identical(other.prompt, prompt) || other.prompt == prompt));
}


@override
int get hashCode => Object.hash(runtimeType,token,pluginId,title,bodyJson,const DeepCollectionEquality().hash(_buttons),prompt);

@override
String toString() {
  return 'PluginDialogModel(token: $token, pluginId: $pluginId, title: $title, bodyJson: $bodyJson, buttons: $buttons, prompt: $prompt)';
}


}

/// @nodoc
abstract mixin class _$PluginDialogModelCopyWith<$Res> implements $PluginDialogModelCopyWith<$Res> {
  factory _$PluginDialogModelCopyWith(_PluginDialogModel value, $Res Function(_PluginDialogModel) _then) = __$PluginDialogModelCopyWithImpl;
@override @useResult
$Res call({
 int token, String pluginId, String title, String bodyJson, List<String> buttons, bool prompt
});




}
/// @nodoc
class __$PluginDialogModelCopyWithImpl<$Res>
    implements _$PluginDialogModelCopyWith<$Res> {
  __$PluginDialogModelCopyWithImpl(this._self, this._then);

  final _PluginDialogModel _self;
  final $Res Function(_PluginDialogModel) _then;

/// Create a copy of PluginDialogModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? pluginId = null,Object? title = null,Object? bodyJson = null,Object? buttons = null,Object? prompt = null,}) {
  return _then(_PluginDialogModel(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,bodyJson: null == bodyJson ? _self.bodyJson : bodyJson // ignore: cast_nullable_to_non_nullable
as String,buttons: null == buttons ? _self._buttons : buttons // ignore: cast_nullable_to_non_nullable
as List<String>,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$PluginCommandRefModel {

 String get id; String get title;
/// Create a copy of PluginCommandRefModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginCommandRefModelCopyWith<PluginCommandRefModel> get copyWith => _$PluginCommandRefModelCopyWithImpl<PluginCommandRefModel>(this as PluginCommandRefModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginCommandRefModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title));
}


@override
int get hashCode => Object.hash(runtimeType,id,title);

@override
String toString() {
  return 'PluginCommandRefModel(id: $id, title: $title)';
}


}

/// @nodoc
abstract mixin class $PluginCommandRefModelCopyWith<$Res>  {
  factory $PluginCommandRefModelCopyWith(PluginCommandRefModel value, $Res Function(PluginCommandRefModel) _then) = _$PluginCommandRefModelCopyWithImpl;
@useResult
$Res call({
 String id, String title
});




}
/// @nodoc
class _$PluginCommandRefModelCopyWithImpl<$Res>
    implements $PluginCommandRefModelCopyWith<$Res> {
  _$PluginCommandRefModelCopyWithImpl(this._self, this._then);

  final PluginCommandRefModel _self;
  final $Res Function(PluginCommandRefModel) _then;

/// Create a copy of PluginCommandRefModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginCommandRefModel].
extension PluginCommandRefModelPatterns on PluginCommandRefModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginCommandRefModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginCommandRefModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginCommandRefModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginCommandRefModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginCommandRefModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginCommandRefModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginCommandRefModel() when $default != null:
return $default(_that.id,_that.title);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title)  $default,) {final _that = this;
switch (_that) {
case _PluginCommandRefModel():
return $default(_that.id,_that.title);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title)?  $default,) {final _that = this;
switch (_that) {
case _PluginCommandRefModel() when $default != null:
return $default(_that.id,_that.title);case _:
  return null;

}
}

}

/// @nodoc


class _PluginCommandRefModel implements PluginCommandRefModel {
  const _PluginCommandRefModel({required this.id, this.title = ''});
  

@override final  String id;
@override@JsonKey() final  String title;

/// Create a copy of PluginCommandRefModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginCommandRefModelCopyWith<_PluginCommandRefModel> get copyWith => __$PluginCommandRefModelCopyWithImpl<_PluginCommandRefModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginCommandRefModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title));
}


@override
int get hashCode => Object.hash(runtimeType,id,title);

@override
String toString() {
  return 'PluginCommandRefModel(id: $id, title: $title)';
}


}

/// @nodoc
abstract mixin class _$PluginCommandRefModelCopyWith<$Res> implements $PluginCommandRefModelCopyWith<$Res> {
  factory _$PluginCommandRefModelCopyWith(_PluginCommandRefModel value, $Res Function(_PluginCommandRefModel) _then) = __$PluginCommandRefModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String title
});




}
/// @nodoc
class __$PluginCommandRefModelCopyWithImpl<$Res>
    implements _$PluginCommandRefModelCopyWith<$Res> {
  __$PluginCommandRefModelCopyWithImpl(this._self, this._then);

  final _PluginCommandRefModel _self;
  final $Res Function(_PluginCommandRefModel) _then;

/// Create a copy of PluginCommandRefModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,}) {
  return _then(_PluginCommandRefModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PluginRefModel {

 String get id; String get name; String get version; String get state; String? get error; String get description; String get directory; String get entryPoint; List<String> get permissions; List<PluginCommandRefModel> get commands; List<String> get log;
/// Create a copy of PluginRefModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginRefModelCopyWith<PluginRefModel> get copyWith => _$PluginRefModelCopyWithImpl<PluginRefModel>(this as PluginRefModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginRefModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.version, version) || other.version == version)&&(identical(other.state, state) || other.state == state)&&(identical(other.error, error) || other.error == error)&&(identical(other.description, description) || other.description == description)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.entryPoint, entryPoint) || other.entryPoint == entryPoint)&&const DeepCollectionEquality().equals(other.permissions, permissions)&&const DeepCollectionEquality().equals(other.commands, commands)&&const DeepCollectionEquality().equals(other.log, log));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,version,state,error,description,directory,entryPoint,const DeepCollectionEquality().hash(permissions),const DeepCollectionEquality().hash(commands),const DeepCollectionEquality().hash(log));

@override
String toString() {
  return 'PluginRefModel(id: $id, name: $name, version: $version, state: $state, error: $error, description: $description, directory: $directory, entryPoint: $entryPoint, permissions: $permissions, commands: $commands, log: $log)';
}


}

/// @nodoc
abstract mixin class $PluginRefModelCopyWith<$Res>  {
  factory $PluginRefModelCopyWith(PluginRefModel value, $Res Function(PluginRefModel) _then) = _$PluginRefModelCopyWithImpl;
@useResult
$Res call({
 String id, String name, String version, String state, String? error, String description, String directory, String entryPoint, List<String> permissions, List<PluginCommandRefModel> commands, List<String> log
});




}
/// @nodoc
class _$PluginRefModelCopyWithImpl<$Res>
    implements $PluginRefModelCopyWith<$Res> {
  _$PluginRefModelCopyWithImpl(this._self, this._then);

  final PluginRefModel _self;
  final $Res Function(PluginRefModel) _then;

/// Create a copy of PluginRefModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? version = null,Object? state = null,Object? error = freezed,Object? description = null,Object? directory = null,Object? entryPoint = null,Object? permissions = null,Object? commands = null,Object? log = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,entryPoint: null == entryPoint ? _self.entryPoint : entryPoint // ignore: cast_nullable_to_non_nullable
as String,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as List<String>,commands: null == commands ? _self.commands : commands // ignore: cast_nullable_to_non_nullable
as List<PluginCommandRefModel>,log: null == log ? _self.log : log // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginRefModel].
extension PluginRefModelPatterns on PluginRefModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginRefModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginRefModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginRefModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginRefModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginRefModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginRefModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String version,  String state,  String? error,  String description,  String directory,  String entryPoint,  List<String> permissions,  List<PluginCommandRefModel> commands,  List<String> log)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginRefModel() when $default != null:
return $default(_that.id,_that.name,_that.version,_that.state,_that.error,_that.description,_that.directory,_that.entryPoint,_that.permissions,_that.commands,_that.log);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String version,  String state,  String? error,  String description,  String directory,  String entryPoint,  List<String> permissions,  List<PluginCommandRefModel> commands,  List<String> log)  $default,) {final _that = this;
switch (_that) {
case _PluginRefModel():
return $default(_that.id,_that.name,_that.version,_that.state,_that.error,_that.description,_that.directory,_that.entryPoint,_that.permissions,_that.commands,_that.log);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String version,  String state,  String? error,  String description,  String directory,  String entryPoint,  List<String> permissions,  List<PluginCommandRefModel> commands,  List<String> log)?  $default,) {final _that = this;
switch (_that) {
case _PluginRefModel() when $default != null:
return $default(_that.id,_that.name,_that.version,_that.state,_that.error,_that.description,_that.directory,_that.entryPoint,_that.permissions,_that.commands,_that.log);case _:
  return null;

}
}

}

/// @nodoc


class _PluginRefModel implements PluginRefModel {
  const _PluginRefModel({required this.id, this.name = '', this.version = '', this.state = 'installed', this.error, this.description = '', this.directory = '', this.entryPoint = 'main.js', final  List<String> permissions = const [], final  List<PluginCommandRefModel> commands = const [], final  List<String> log = const []}): _permissions = permissions,_commands = commands,_log = log;
  

@override final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String version;
@override@JsonKey() final  String state;
@override final  String? error;
@override@JsonKey() final  String description;
@override@JsonKey() final  String directory;
@override@JsonKey() final  String entryPoint;
 final  List<String> _permissions;
@override@JsonKey() List<String> get permissions {
  if (_permissions is EqualUnmodifiableListView) return _permissions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_permissions);
}

 final  List<PluginCommandRefModel> _commands;
@override@JsonKey() List<PluginCommandRefModel> get commands {
  if (_commands is EqualUnmodifiableListView) return _commands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_commands);
}

 final  List<String> _log;
@override@JsonKey() List<String> get log {
  if (_log is EqualUnmodifiableListView) return _log;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_log);
}


/// Create a copy of PluginRefModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginRefModelCopyWith<_PluginRefModel> get copyWith => __$PluginRefModelCopyWithImpl<_PluginRefModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginRefModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.version, version) || other.version == version)&&(identical(other.state, state) || other.state == state)&&(identical(other.error, error) || other.error == error)&&(identical(other.description, description) || other.description == description)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.entryPoint, entryPoint) || other.entryPoint == entryPoint)&&const DeepCollectionEquality().equals(other._permissions, _permissions)&&const DeepCollectionEquality().equals(other._commands, _commands)&&const DeepCollectionEquality().equals(other._log, _log));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,version,state,error,description,directory,entryPoint,const DeepCollectionEquality().hash(_permissions),const DeepCollectionEquality().hash(_commands),const DeepCollectionEquality().hash(_log));

@override
String toString() {
  return 'PluginRefModel(id: $id, name: $name, version: $version, state: $state, error: $error, description: $description, directory: $directory, entryPoint: $entryPoint, permissions: $permissions, commands: $commands, log: $log)';
}


}

/// @nodoc
abstract mixin class _$PluginRefModelCopyWith<$Res> implements $PluginRefModelCopyWith<$Res> {
  factory _$PluginRefModelCopyWith(_PluginRefModel value, $Res Function(_PluginRefModel) _then) = __$PluginRefModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String version, String state, String? error, String description, String directory, String entryPoint, List<String> permissions, List<PluginCommandRefModel> commands, List<String> log
});




}
/// @nodoc
class __$PluginRefModelCopyWithImpl<$Res>
    implements _$PluginRefModelCopyWith<$Res> {
  __$PluginRefModelCopyWithImpl(this._self, this._then);

  final _PluginRefModel _self;
  final $Res Function(_PluginRefModel) _then;

/// Create a copy of PluginRefModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? version = null,Object? state = null,Object? error = freezed,Object? description = null,Object? directory = null,Object? entryPoint = null,Object? permissions = null,Object? commands = null,Object? log = null,}) {
  return _then(_PluginRefModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,entryPoint: null == entryPoint ? _self.entryPoint : entryPoint // ignore: cast_nullable_to_non_nullable
as String,permissions: null == permissions ? _self._permissions : permissions // ignore: cast_nullable_to_non_nullable
as List<String>,commands: null == commands ? _self._commands : commands // ignore: cast_nullable_to_non_nullable
as List<PluginCommandRefModel>,log: null == log ? _self._log : log // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$PluginModel {

 bool get started; String get directory; List<PluginRefModel> get plugins; List<PluginPanelModel> get panels; Map<String, String> get viewTrees; PluginDialogModel? get dialog; int get epoch;
/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginModelCopyWith<PluginModel> get copyWith => _$PluginModelCopyWithImpl<PluginModel>(this as PluginModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginModel&&(identical(other.started, started) || other.started == started)&&(identical(other.directory, directory) || other.directory == directory)&&const DeepCollectionEquality().equals(other.plugins, plugins)&&const DeepCollectionEquality().equals(other.panels, panels)&&const DeepCollectionEquality().equals(other.viewTrees, viewTrees)&&(identical(other.dialog, dialog) || other.dialog == dialog)&&(identical(other.epoch, epoch) || other.epoch == epoch));
}


@override
int get hashCode => Object.hash(runtimeType,started,directory,const DeepCollectionEquality().hash(plugins),const DeepCollectionEquality().hash(panels),const DeepCollectionEquality().hash(viewTrees),dialog,epoch);

@override
String toString() {
  return 'PluginModel(started: $started, directory: $directory, plugins: $plugins, panels: $panels, viewTrees: $viewTrees, dialog: $dialog, epoch: $epoch)';
}


}

/// @nodoc
abstract mixin class $PluginModelCopyWith<$Res>  {
  factory $PluginModelCopyWith(PluginModel value, $Res Function(PluginModel) _then) = _$PluginModelCopyWithImpl;
@useResult
$Res call({
 bool started, String directory, List<PluginRefModel> plugins, List<PluginPanelModel> panels, Map<String, String> viewTrees, PluginDialogModel? dialog, int epoch
});


$PluginDialogModelCopyWith<$Res>? get dialog;

}
/// @nodoc
class _$PluginModelCopyWithImpl<$Res>
    implements $PluginModelCopyWith<$Res> {
  _$PluginModelCopyWithImpl(this._self, this._then);

  final PluginModel _self;
  final $Res Function(PluginModel) _then;

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? started = null,Object? directory = null,Object? plugins = null,Object? panels = null,Object? viewTrees = null,Object? dialog = freezed,Object? epoch = null,}) {
  return _then(_self.copyWith(
started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,plugins: null == plugins ? _self.plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginRefModel>,panels: null == panels ? _self.panels : panels // ignore: cast_nullable_to_non_nullable
as List<PluginPanelModel>,viewTrees: null == viewTrees ? _self.viewTrees : viewTrees // ignore: cast_nullable_to_non_nullable
as Map<String, String>,dialog: freezed == dialog ? _self.dialog : dialog // ignore: cast_nullable_to_non_nullable
as PluginDialogModel?,epoch: null == epoch ? _self.epoch : epoch // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginDialogModelCopyWith<$Res>? get dialog {
    if (_self.dialog == null) {
    return null;
  }

  return $PluginDialogModelCopyWith<$Res>(_self.dialog!, (value) {
    return _then(_self.copyWith(dialog: value));
  });
}
}


/// Adds pattern-matching-related methods to [PluginModel].
extension PluginModelPatterns on PluginModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginModel value)  $default,){
final _that = this;
switch (_that) {
case _PluginModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginModel value)?  $default,){
final _that = this;
switch (_that) {
case _PluginModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool started,  String directory,  List<PluginRefModel> plugins,  List<PluginPanelModel> panels,  Map<String, String> viewTrees,  PluginDialogModel? dialog,  int epoch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginModel() when $default != null:
return $default(_that.started,_that.directory,_that.plugins,_that.panels,_that.viewTrees,_that.dialog,_that.epoch);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool started,  String directory,  List<PluginRefModel> plugins,  List<PluginPanelModel> panels,  Map<String, String> viewTrees,  PluginDialogModel? dialog,  int epoch)  $default,) {final _that = this;
switch (_that) {
case _PluginModel():
return $default(_that.started,_that.directory,_that.plugins,_that.panels,_that.viewTrees,_that.dialog,_that.epoch);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool started,  String directory,  List<PluginRefModel> plugins,  List<PluginPanelModel> panels,  Map<String, String> viewTrees,  PluginDialogModel? dialog,  int epoch)?  $default,) {final _that = this;
switch (_that) {
case _PluginModel() when $default != null:
return $default(_that.started,_that.directory,_that.plugins,_that.panels,_that.viewTrees,_that.dialog,_that.epoch);case _:
  return null;

}
}

}

/// @nodoc


class _PluginModel implements PluginModel {
  const _PluginModel({this.started = false, this.directory = '', final  List<PluginRefModel> plugins = const [], final  List<PluginPanelModel> panels = const [], final  Map<String, String> viewTrees = const {}, this.dialog, this.epoch = 0}): _plugins = plugins,_panels = panels,_viewTrees = viewTrees;
  

@override@JsonKey() final  bool started;
@override@JsonKey() final  String directory;
 final  List<PluginRefModel> _plugins;
@override@JsonKey() List<PluginRefModel> get plugins {
  if (_plugins is EqualUnmodifiableListView) return _plugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plugins);
}

 final  List<PluginPanelModel> _panels;
@override@JsonKey() List<PluginPanelModel> get panels {
  if (_panels is EqualUnmodifiableListView) return _panels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_panels);
}

 final  Map<String, String> _viewTrees;
@override@JsonKey() Map<String, String> get viewTrees {
  if (_viewTrees is EqualUnmodifiableMapView) return _viewTrees;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_viewTrees);
}

@override final  PluginDialogModel? dialog;
@override@JsonKey() final  int epoch;

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginModelCopyWith<_PluginModel> get copyWith => __$PluginModelCopyWithImpl<_PluginModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginModel&&(identical(other.started, started) || other.started == started)&&(identical(other.directory, directory) || other.directory == directory)&&const DeepCollectionEquality().equals(other._plugins, _plugins)&&const DeepCollectionEquality().equals(other._panels, _panels)&&const DeepCollectionEquality().equals(other._viewTrees, _viewTrees)&&(identical(other.dialog, dialog) || other.dialog == dialog)&&(identical(other.epoch, epoch) || other.epoch == epoch));
}


@override
int get hashCode => Object.hash(runtimeType,started,directory,const DeepCollectionEquality().hash(_plugins),const DeepCollectionEquality().hash(_panels),const DeepCollectionEquality().hash(_viewTrees),dialog,epoch);

@override
String toString() {
  return 'PluginModel(started: $started, directory: $directory, plugins: $plugins, panels: $panels, viewTrees: $viewTrees, dialog: $dialog, epoch: $epoch)';
}


}

/// @nodoc
abstract mixin class _$PluginModelCopyWith<$Res> implements $PluginModelCopyWith<$Res> {
  factory _$PluginModelCopyWith(_PluginModel value, $Res Function(_PluginModel) _then) = __$PluginModelCopyWithImpl;
@override @useResult
$Res call({
 bool started, String directory, List<PluginRefModel> plugins, List<PluginPanelModel> panels, Map<String, String> viewTrees, PluginDialogModel? dialog, int epoch
});


@override $PluginDialogModelCopyWith<$Res>? get dialog;

}
/// @nodoc
class __$PluginModelCopyWithImpl<$Res>
    implements _$PluginModelCopyWith<$Res> {
  __$PluginModelCopyWithImpl(this._self, this._then);

  final _PluginModel _self;
  final $Res Function(_PluginModel) _then;

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? started = null,Object? directory = null,Object? plugins = null,Object? panels = null,Object? viewTrees = null,Object? dialog = freezed,Object? epoch = null,}) {
  return _then(_PluginModel(
started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,plugins: null == plugins ? _self._plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginRefModel>,panels: null == panels ? _self._panels : panels // ignore: cast_nullable_to_non_nullable
as List<PluginPanelModel>,viewTrees: null == viewTrees ? _self._viewTrees : viewTrees // ignore: cast_nullable_to_non_nullable
as Map<String, String>,dialog: freezed == dialog ? _self.dialog : dialog // ignore: cast_nullable_to_non_nullable
as PluginDialogModel?,epoch: null == epoch ? _self.epoch : epoch // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginDialogModelCopyWith<$Res>? get dialog {
    if (_self.dialog == null) {
    return null;
  }

  return $PluginDialogModelCopyWith<$Res>(_self.dialog!, (value) {
    return _then(_self.copyWith(dialog: value));
  });
}
}

// dart format on
