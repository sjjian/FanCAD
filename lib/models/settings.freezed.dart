// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppearanceModel {

 ThemePreference get theme; String get language;
/// Create a copy of AppearanceModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppearanceModelCopyWith<AppearanceModel> get copyWith => _$AppearanceModelCopyWithImpl<AppearanceModel>(this as AppearanceModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppearanceModel&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.language, language) || other.language == language));
}


@override
int get hashCode => Object.hash(runtimeType,theme,language);

@override
String toString() {
  return 'AppearanceModel(theme: $theme, language: $language)';
}


}

/// @nodoc
abstract mixin class $AppearanceModelCopyWith<$Res>  {
  factory $AppearanceModelCopyWith(AppearanceModel value, $Res Function(AppearanceModel) _then) = _$AppearanceModelCopyWithImpl;
@useResult
$Res call({
 ThemePreference theme, String language
});




}
/// @nodoc
class _$AppearanceModelCopyWithImpl<$Res>
    implements $AppearanceModelCopyWith<$Res> {
  _$AppearanceModelCopyWithImpl(this._self, this._then);

  final AppearanceModel _self;
  final $Res Function(AppearanceModel) _then;

/// Create a copy of AppearanceModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? theme = null,Object? language = null,}) {
  return _then(_self.copyWith(
theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemePreference,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AppearanceModel].
extension AppearanceModelPatterns on AppearanceModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppearanceModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppearanceModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppearanceModel value)  $default,){
final _that = this;
switch (_that) {
case _AppearanceModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppearanceModel value)?  $default,){
final _that = this;
switch (_that) {
case _AppearanceModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ThemePreference theme,  String language)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppearanceModel() when $default != null:
return $default(_that.theme,_that.language);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ThemePreference theme,  String language)  $default,) {final _that = this;
switch (_that) {
case _AppearanceModel():
return $default(_that.theme,_that.language);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ThemePreference theme,  String language)?  $default,) {final _that = this;
switch (_that) {
case _AppearanceModel() when $default != null:
return $default(_that.theme,_that.language);case _:
  return null;

}
}

}

/// @nodoc


class _AppearanceModel implements AppearanceModel {
  const _AppearanceModel({this.theme = ThemePreference.fallback, this.language = FanCadLanguage.english});
  

@override@JsonKey() final  ThemePreference theme;
@override@JsonKey() final  String language;

/// Create a copy of AppearanceModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppearanceModelCopyWith<_AppearanceModel> get copyWith => __$AppearanceModelCopyWithImpl<_AppearanceModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppearanceModel&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.language, language) || other.language == language));
}


@override
int get hashCode => Object.hash(runtimeType,theme,language);

@override
String toString() {
  return 'AppearanceModel(theme: $theme, language: $language)';
}


}

/// @nodoc
abstract mixin class _$AppearanceModelCopyWith<$Res> implements $AppearanceModelCopyWith<$Res> {
  factory _$AppearanceModelCopyWith(_AppearanceModel value, $Res Function(_AppearanceModel) _then) = __$AppearanceModelCopyWithImpl;
@override @useResult
$Res call({
 ThemePreference theme, String language
});




}
/// @nodoc
class __$AppearanceModelCopyWithImpl<$Res>
    implements _$AppearanceModelCopyWith<$Res> {
  __$AppearanceModelCopyWithImpl(this._self, this._then);

  final _AppearanceModel _self;
  final $Res Function(_AppearanceModel) _then;

/// Create a copy of AppearanceModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? theme = null,Object? language = null,}) {
  return _then(_AppearanceModel(
theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemePreference,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$McpModel {

 McpBindModel get bind; String get token;
/// Create a copy of McpModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpModelCopyWith<McpModel> get copyWith => _$McpModelCopyWithImpl<McpModel>(this as McpModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpModel&&(identical(other.bind, bind) || other.bind == bind)&&(identical(other.token, token) || other.token == token));
}


@override
int get hashCode => Object.hash(runtimeType,bind,token);

@override
String toString() {
  return 'McpModel(bind: $bind, token: $token)';
}


}

/// @nodoc
abstract mixin class $McpModelCopyWith<$Res>  {
  factory $McpModelCopyWith(McpModel value, $Res Function(McpModel) _then) = _$McpModelCopyWithImpl;
@useResult
$Res call({
 McpBindModel bind, String token
});


$McpBindModelCopyWith<$Res> get bind;

}
/// @nodoc
class _$McpModelCopyWithImpl<$Res>
    implements $McpModelCopyWith<$Res> {
  _$McpModelCopyWithImpl(this._self, this._then);

  final McpModel _self;
  final $Res Function(McpModel) _then;

/// Create a copy of McpModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bind = null,Object? token = null,}) {
  return _then(_self.copyWith(
bind: null == bind ? _self.bind : bind // ignore: cast_nullable_to_non_nullable
as McpBindModel,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of McpModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$McpBindModelCopyWith<$Res> get bind {
  
  return $McpBindModelCopyWith<$Res>(_self.bind, (value) {
    return _then(_self.copyWith(bind: value));
  });
}
}


/// Adds pattern-matching-related methods to [McpModel].
extension McpModelPatterns on McpModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpModel value)  $default,){
final _that = this;
switch (_that) {
case _McpModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpModel value)?  $default,){
final _that = this;
switch (_that) {
case _McpModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( McpBindModel bind,  String token)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpModel() when $default != null:
return $default(_that.bind,_that.token);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( McpBindModel bind,  String token)  $default,) {final _that = this;
switch (_that) {
case _McpModel():
return $default(_that.bind,_that.token);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( McpBindModel bind,  String token)?  $default,) {final _that = this;
switch (_that) {
case _McpModel() when $default != null:
return $default(_that.bind,_that.token);case _:
  return null;

}
}

}

/// @nodoc


class _McpModel extends McpModel {
  const _McpModel({required this.bind, this.token = ''}): super._();
  

@override final  McpBindModel bind;
@override@JsonKey() final  String token;

/// Create a copy of McpModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpModelCopyWith<_McpModel> get copyWith => __$McpModelCopyWithImpl<_McpModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpModel&&(identical(other.bind, bind) || other.bind == bind)&&(identical(other.token, token) || other.token == token));
}


@override
int get hashCode => Object.hash(runtimeType,bind,token);

@override
String toString() {
  return 'McpModel(bind: $bind, token: $token)';
}


}

/// @nodoc
abstract mixin class _$McpModelCopyWith<$Res> implements $McpModelCopyWith<$Res> {
  factory _$McpModelCopyWith(_McpModel value, $Res Function(_McpModel) _then) = __$McpModelCopyWithImpl;
@override @useResult
$Res call({
 McpBindModel bind, String token
});


@override $McpBindModelCopyWith<$Res> get bind;

}
/// @nodoc
class __$McpModelCopyWithImpl<$Res>
    implements _$McpModelCopyWith<$Res> {
  __$McpModelCopyWithImpl(this._self, this._then);

  final _McpModel _self;
  final $Res Function(_McpModel) _then;

/// Create a copy of McpModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bind = null,Object? token = null,}) {
  return _then(_McpModel(
bind: null == bind ? _self.bind : bind // ignore: cast_nullable_to_non_nullable
as McpBindModel,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of McpModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$McpBindModelCopyWith<$Res> get bind {
  
  return $McpBindModelCopyWith<$Res>(_self.bind, (value) {
    return _then(_self.copyWith(bind: value));
  });
}
}

/// @nodoc
mixin _$McpBindModel {

 bool get enabled; int get port; bool get local; List<String> get allowlist;
/// Create a copy of McpBindModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpBindModelCopyWith<McpBindModel> get copyWith => _$McpBindModelCopyWithImpl<McpBindModel>(this as McpBindModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpBindModel&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.port, port) || other.port == port)&&(identical(other.local, local) || other.local == local)&&const DeepCollectionEquality().equals(other.allowlist, allowlist));
}


@override
int get hashCode => Object.hash(runtimeType,enabled,port,local,const DeepCollectionEquality().hash(allowlist));

@override
String toString() {
  return 'McpBindModel(enabled: $enabled, port: $port, local: $local, allowlist: $allowlist)';
}


}

/// @nodoc
abstract mixin class $McpBindModelCopyWith<$Res>  {
  factory $McpBindModelCopyWith(McpBindModel value, $Res Function(McpBindModel) _then) = _$McpBindModelCopyWithImpl;
@useResult
$Res call({
 bool enabled, int port, bool local, List<String> allowlist
});




}
/// @nodoc
class _$McpBindModelCopyWithImpl<$Res>
    implements $McpBindModelCopyWith<$Res> {
  _$McpBindModelCopyWithImpl(this._self, this._then);

  final McpBindModel _self;
  final $Res Function(McpBindModel) _then;

/// Create a copy of McpBindModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? port = null,Object? local = null,Object? allowlist = null,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,local: null == local ? _self.local : local // ignore: cast_nullable_to_non_nullable
as bool,allowlist: null == allowlist ? _self.allowlist : allowlist // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [McpBindModel].
extension McpBindModelPatterns on McpBindModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpBindModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpBindModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpBindModel value)  $default,){
final _that = this;
switch (_that) {
case _McpBindModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpBindModel value)?  $default,){
final _that = this;
switch (_that) {
case _McpBindModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  int port,  bool local,  List<String> allowlist)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpBindModel() when $default != null:
return $default(_that.enabled,_that.port,_that.local,_that.allowlist);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  int port,  bool local,  List<String> allowlist)  $default,) {final _that = this;
switch (_that) {
case _McpBindModel():
return $default(_that.enabled,_that.port,_that.local,_that.allowlist);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  int port,  bool local,  List<String> allowlist)?  $default,) {final _that = this;
switch (_that) {
case _McpBindModel() when $default != null:
return $default(_that.enabled,_that.port,_that.local,_that.allowlist);case _:
  return null;

}
}

}

/// @nodoc


class _McpBindModel extends McpBindModel {
  const _McpBindModel({required this.enabled, required this.port, required this.local, required final  List<String> allowlist}): _allowlist = allowlist,super._();
  

@override final  bool enabled;
@override final  int port;
@override final  bool local;
 final  List<String> _allowlist;
@override List<String> get allowlist {
  if (_allowlist is EqualUnmodifiableListView) return _allowlist;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allowlist);
}


/// Create a copy of McpBindModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpBindModelCopyWith<_McpBindModel> get copyWith => __$McpBindModelCopyWithImpl<_McpBindModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpBindModel&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.port, port) || other.port == port)&&(identical(other.local, local) || other.local == local)&&const DeepCollectionEquality().equals(other._allowlist, _allowlist));
}


@override
int get hashCode => Object.hash(runtimeType,enabled,port,local,const DeepCollectionEquality().hash(_allowlist));

@override
String toString() {
  return 'McpBindModel(enabled: $enabled, port: $port, local: $local, allowlist: $allowlist)';
}


}

/// @nodoc
abstract mixin class _$McpBindModelCopyWith<$Res> implements $McpBindModelCopyWith<$Res> {
  factory _$McpBindModelCopyWith(_McpBindModel value, $Res Function(_McpBindModel) _then) = __$McpBindModelCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, int port, bool local, List<String> allowlist
});




}
/// @nodoc
class __$McpBindModelCopyWithImpl<$Res>
    implements _$McpBindModelCopyWith<$Res> {
  __$McpBindModelCopyWithImpl(this._self, this._then);

  final _McpBindModel _self;
  final $Res Function(_McpBindModel) _then;

/// Create a copy of McpBindModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? port = null,Object? local = null,Object? allowlist = null,}) {
  return _then(_McpBindModel(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,local: null == local ? _self.local : local // ignore: cast_nullable_to_non_nullable
as bool,allowlist: null == allowlist ? _self._allowlist : allowlist // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$McpClientEndpointModel {

 String get url; String get token;
/// Create a copy of McpClientEndpointModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McpClientEndpointModelCopyWith<McpClientEndpointModel> get copyWith => _$McpClientEndpointModelCopyWithImpl<McpClientEndpointModel>(this as McpClientEndpointModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpClientEndpointModel&&(identical(other.url, url) || other.url == url)&&(identical(other.token, token) || other.token == token));
}


@override
int get hashCode => Object.hash(runtimeType,url,token);

@override
String toString() {
  return 'McpClientEndpointModel(url: $url, token: $token)';
}


}

/// @nodoc
abstract mixin class $McpClientEndpointModelCopyWith<$Res>  {
  factory $McpClientEndpointModelCopyWith(McpClientEndpointModel value, $Res Function(McpClientEndpointModel) _then) = _$McpClientEndpointModelCopyWithImpl;
@useResult
$Res call({
 String url, String token
});




}
/// @nodoc
class _$McpClientEndpointModelCopyWithImpl<$Res>
    implements $McpClientEndpointModelCopyWith<$Res> {
  _$McpClientEndpointModelCopyWithImpl(this._self, this._then);

  final McpClientEndpointModel _self;
  final $Res Function(McpClientEndpointModel) _then;

/// Create a copy of McpClientEndpointModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? token = null,}) {
  return _then(_self.copyWith(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [McpClientEndpointModel].
extension McpClientEndpointModelPatterns on McpClientEndpointModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McpClientEndpointModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McpClientEndpointModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McpClientEndpointModel value)  $default,){
final _that = this;
switch (_that) {
case _McpClientEndpointModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McpClientEndpointModel value)?  $default,){
final _that = this;
switch (_that) {
case _McpClientEndpointModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  String token)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McpClientEndpointModel() when $default != null:
return $default(_that.url,_that.token);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  String token)  $default,) {final _that = this;
switch (_that) {
case _McpClientEndpointModel():
return $default(_that.url,_that.token);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  String token)?  $default,) {final _that = this;
switch (_that) {
case _McpClientEndpointModel() when $default != null:
return $default(_that.url,_that.token);case _:
  return null;

}
}

}

/// @nodoc


class _McpClientEndpointModel extends McpClientEndpointModel {
  const _McpClientEndpointModel({required this.url, required this.token}): super._();
  

@override final  String url;
@override final  String token;

/// Create a copy of McpClientEndpointModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McpClientEndpointModelCopyWith<_McpClientEndpointModel> get copyWith => __$McpClientEndpointModelCopyWithImpl<_McpClientEndpointModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpClientEndpointModel&&(identical(other.url, url) || other.url == url)&&(identical(other.token, token) || other.token == token));
}


@override
int get hashCode => Object.hash(runtimeType,url,token);

@override
String toString() {
  return 'McpClientEndpointModel(url: $url, token: $token)';
}


}

/// @nodoc
abstract mixin class _$McpClientEndpointModelCopyWith<$Res> implements $McpClientEndpointModelCopyWith<$Res> {
  factory _$McpClientEndpointModelCopyWith(_McpClientEndpointModel value, $Res Function(_McpClientEndpointModel) _then) = __$McpClientEndpointModelCopyWithImpl;
@override @useResult
$Res call({
 String url, String token
});




}
/// @nodoc
class __$McpClientEndpointModelCopyWithImpl<$Res>
    implements _$McpClientEndpointModelCopyWith<$Res> {
  __$McpClientEndpointModelCopyWithImpl(this._self, this._then);

  final _McpClientEndpointModel _self;
  final $Res Function(_McpClientEndpointModel) _then;

/// Create a copy of McpClientEndpointModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? token = null,}) {
  return _then(_McpClientEndpointModel(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AssistantProfileModel {

 String get id; String get label; String get model; String get baseUrl; String get apiKey;
/// Create a copy of AssistantProfileModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantProfileModelCopyWith<AssistantProfileModel> get copyWith => _$AssistantProfileModelCopyWithImpl<AssistantProfileModel>(this as AssistantProfileModel, _$identity);

  /// Serializes this AssistantProfileModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantProfileModel&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.model, model) || other.model == model)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,model,baseUrl,apiKey);

@override
String toString() {
  return 'AssistantProfileModel(id: $id, label: $label, model: $model, baseUrl: $baseUrl, apiKey: $apiKey)';
}


}

/// @nodoc
abstract mixin class $AssistantProfileModelCopyWith<$Res>  {
  factory $AssistantProfileModelCopyWith(AssistantProfileModel value, $Res Function(AssistantProfileModel) _then) = _$AssistantProfileModelCopyWithImpl;
@useResult
$Res call({
 String id, String label, String model, String baseUrl, String apiKey
});




}
/// @nodoc
class _$AssistantProfileModelCopyWithImpl<$Res>
    implements $AssistantProfileModelCopyWith<$Res> {
  _$AssistantProfileModelCopyWithImpl(this._self, this._then);

  final AssistantProfileModel _self;
  final $Res Function(AssistantProfileModel) _then;

/// Create a copy of AssistantProfileModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? model = null,Object? baseUrl = null,Object? apiKey = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AssistantProfileModel].
extension AssistantProfileModelPatterns on AssistantProfileModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssistantProfileModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantProfileModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssistantProfileModel value)  $default,){
final _that = this;
switch (_that) {
case _AssistantProfileModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssistantProfileModel value)?  $default,){
final _that = this;
switch (_that) {
case _AssistantProfileModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  String model,  String baseUrl,  String apiKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssistantProfileModel() when $default != null:
return $default(_that.id,_that.label,_that.model,_that.baseUrl,_that.apiKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  String model,  String baseUrl,  String apiKey)  $default,) {final _that = this;
switch (_that) {
case _AssistantProfileModel():
return $default(_that.id,_that.label,_that.model,_that.baseUrl,_that.apiKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  String model,  String baseUrl,  String apiKey)?  $default,) {final _that = this;
switch (_that) {
case _AssistantProfileModel() when $default != null:
return $default(_that.id,_that.label,_that.model,_that.baseUrl,_that.apiKey);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable()
class _AssistantProfileModel extends AssistantProfileModel {
  const _AssistantProfileModel({required this.id, this.label = '', this.model = 'gpt-4o-mini', this.baseUrl = 'https://api.openai.com/v1', this.apiKey = ''}): super._();
  factory _AssistantProfileModel.fromJson(Map<String, dynamic> json) => _$AssistantProfileModelFromJson(json);

@override final  String id;
@override@JsonKey() final  String label;
@override@JsonKey() final  String model;
@override@JsonKey() final  String baseUrl;
@override@JsonKey() final  String apiKey;

/// Create a copy of AssistantProfileModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantProfileModelCopyWith<_AssistantProfileModel> get copyWith => __$AssistantProfileModelCopyWithImpl<_AssistantProfileModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssistantProfileModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantProfileModel&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.model, model) || other.model == model)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,model,baseUrl,apiKey);

@override
String toString() {
  return 'AssistantProfileModel(id: $id, label: $label, model: $model, baseUrl: $baseUrl, apiKey: $apiKey)';
}


}

/// @nodoc
abstract mixin class _$AssistantProfileModelCopyWith<$Res> implements $AssistantProfileModelCopyWith<$Res> {
  factory _$AssistantProfileModelCopyWith(_AssistantProfileModel value, $Res Function(_AssistantProfileModel) _then) = __$AssistantProfileModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, String model, String baseUrl, String apiKey
});




}
/// @nodoc
class __$AssistantProfileModelCopyWithImpl<$Res>
    implements _$AssistantProfileModelCopyWith<$Res> {
  __$AssistantProfileModelCopyWithImpl(this._self, this._then);

  final _AssistantProfileModel _self;
  final $Res Function(_AssistantProfileModel) _then;

/// Create a copy of AssistantProfileModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? model = null,Object? baseUrl = null,Object? apiKey = null,}) {
  return _then(_AssistantProfileModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$AssistantAccountsModel {

 List<AssistantProfileModel> get profiles; String get activeProfileId; String get apiKeyRef; bool get autoApprove;
/// Create a copy of AssistantAccountsModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantAccountsModelCopyWith<AssistantAccountsModel> get copyWith => _$AssistantAccountsModelCopyWithImpl<AssistantAccountsModel>(this as AssistantAccountsModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantAccountsModel&&const DeepCollectionEquality().equals(other.profiles, profiles)&&(identical(other.activeProfileId, activeProfileId) || other.activeProfileId == activeProfileId)&&(identical(other.apiKeyRef, apiKeyRef) || other.apiKeyRef == apiKeyRef)&&(identical(other.autoApprove, autoApprove) || other.autoApprove == autoApprove));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(profiles),activeProfileId,apiKeyRef,autoApprove);

@override
String toString() {
  return 'AssistantAccountsModel(profiles: $profiles, activeProfileId: $activeProfileId, apiKeyRef: $apiKeyRef, autoApprove: $autoApprove)';
}


}

/// @nodoc
abstract mixin class $AssistantAccountsModelCopyWith<$Res>  {
  factory $AssistantAccountsModelCopyWith(AssistantAccountsModel value, $Res Function(AssistantAccountsModel) _then) = _$AssistantAccountsModelCopyWithImpl;
@useResult
$Res call({
 List<AssistantProfileModel> profiles, String activeProfileId, String apiKeyRef, bool autoApprove
});




}
/// @nodoc
class _$AssistantAccountsModelCopyWithImpl<$Res>
    implements $AssistantAccountsModelCopyWith<$Res> {
  _$AssistantAccountsModelCopyWithImpl(this._self, this._then);

  final AssistantAccountsModel _self;
  final $Res Function(AssistantAccountsModel) _then;

/// Create a copy of AssistantAccountsModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profiles = null,Object? activeProfileId = null,Object? apiKeyRef = null,Object? autoApprove = null,}) {
  return _then(_self.copyWith(
profiles: null == profiles ? _self.profiles : profiles // ignore: cast_nullable_to_non_nullable
as List<AssistantProfileModel>,activeProfileId: null == activeProfileId ? _self.activeProfileId : activeProfileId // ignore: cast_nullable_to_non_nullable
as String,apiKeyRef: null == apiKeyRef ? _self.apiKeyRef : apiKeyRef // ignore: cast_nullable_to_non_nullable
as String,autoApprove: null == autoApprove ? _self.autoApprove : autoApprove // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AssistantAccountsModel].
extension AssistantAccountsModelPatterns on AssistantAccountsModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssistantAccountsModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantAccountsModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssistantAccountsModel value)  $default,){
final _that = this;
switch (_that) {
case _AssistantAccountsModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssistantAccountsModel value)?  $default,){
final _that = this;
switch (_that) {
case _AssistantAccountsModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AssistantProfileModel> profiles,  String activeProfileId,  String apiKeyRef,  bool autoApprove)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssistantAccountsModel() when $default != null:
return $default(_that.profiles,_that.activeProfileId,_that.apiKeyRef,_that.autoApprove);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AssistantProfileModel> profiles,  String activeProfileId,  String apiKeyRef,  bool autoApprove)  $default,) {final _that = this;
switch (_that) {
case _AssistantAccountsModel():
return $default(_that.profiles,_that.activeProfileId,_that.apiKeyRef,_that.autoApprove);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AssistantProfileModel> profiles,  String activeProfileId,  String apiKeyRef,  bool autoApprove)?  $default,) {final _that = this;
switch (_that) {
case _AssistantAccountsModel() when $default != null:
return $default(_that.profiles,_that.activeProfileId,_that.apiKeyRef,_that.autoApprove);case _:
  return null;

}
}

}

/// @nodoc


class _AssistantAccountsModel extends AssistantAccountsModel {
  const _AssistantAccountsModel({final  List<AssistantProfileModel> profiles = const [], this.activeProfileId = AssistantProfileModel.defaultId, this.apiKeyRef = 'OPENAI_API_KEY', this.autoApprove = false}): _profiles = profiles,super._();
  

 final  List<AssistantProfileModel> _profiles;
@override@JsonKey() List<AssistantProfileModel> get profiles {
  if (_profiles is EqualUnmodifiableListView) return _profiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_profiles);
}

@override@JsonKey() final  String activeProfileId;
@override@JsonKey() final  String apiKeyRef;
@override@JsonKey() final  bool autoApprove;

/// Create a copy of AssistantAccountsModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantAccountsModelCopyWith<_AssistantAccountsModel> get copyWith => __$AssistantAccountsModelCopyWithImpl<_AssistantAccountsModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantAccountsModel&&const DeepCollectionEquality().equals(other._profiles, _profiles)&&(identical(other.activeProfileId, activeProfileId) || other.activeProfileId == activeProfileId)&&(identical(other.apiKeyRef, apiKeyRef) || other.apiKeyRef == apiKeyRef)&&(identical(other.autoApprove, autoApprove) || other.autoApprove == autoApprove));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_profiles),activeProfileId,apiKeyRef,autoApprove);

@override
String toString() {
  return 'AssistantAccountsModel(profiles: $profiles, activeProfileId: $activeProfileId, apiKeyRef: $apiKeyRef, autoApprove: $autoApprove)';
}


}

/// @nodoc
abstract mixin class _$AssistantAccountsModelCopyWith<$Res> implements $AssistantAccountsModelCopyWith<$Res> {
  factory _$AssistantAccountsModelCopyWith(_AssistantAccountsModel value, $Res Function(_AssistantAccountsModel) _then) = __$AssistantAccountsModelCopyWithImpl;
@override @useResult
$Res call({
 List<AssistantProfileModel> profiles, String activeProfileId, String apiKeyRef, bool autoApprove
});




}
/// @nodoc
class __$AssistantAccountsModelCopyWithImpl<$Res>
    implements _$AssistantAccountsModelCopyWith<$Res> {
  __$AssistantAccountsModelCopyWithImpl(this._self, this._then);

  final _AssistantAccountsModel _self;
  final $Res Function(_AssistantAccountsModel) _then;

/// Create a copy of AssistantAccountsModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profiles = null,Object? activeProfileId = null,Object? apiKeyRef = null,Object? autoApprove = null,}) {
  return _then(_AssistantAccountsModel(
profiles: null == profiles ? _self._profiles : profiles // ignore: cast_nullable_to_non_nullable
as List<AssistantProfileModel>,activeProfileId: null == activeProfileId ? _self.activeProfileId : activeProfileId // ignore: cast_nullable_to_non_nullable
as String,apiKeyRef: null == apiKeyRef ? _self.apiKeyRef : apiKeyRef // ignore: cast_nullable_to_non_nullable
as String,autoApprove: null == autoApprove ? _self.autoApprove : autoApprove // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
