// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'canvas_database.dart';

// ignore_for_file: type=lint
class $CanvasProjectsTable extends CanvasProjects
    with TableInfo<$CanvasProjectsTable, CanvasProject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CanvasProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fpsMeta = const VerificationMeta('fps');
  @override
  late final GeneratedColumn<double> fps = GeneratedColumn<double>(
    'fps',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backgroundKindMeta = const VerificationMeta(
    'backgroundKind',
  );
  @override
  late final GeneratedColumn<String> backgroundKind = GeneratedColumn<String>(
    'background_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backgroundColorMeta = const VerificationMeta(
    'backgroundColor',
  );
  @override
  late final GeneratedColumn<int> backgroundColor = GeneratedColumn<int>(
    'background_color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backgroundImagePathMeta =
      const VerificationMeta('backgroundImagePath');
  @override
  late final GeneratedColumn<String> backgroundImagePath =
      GeneratedColumn<String>(
        'background_image_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _documentJsonMeta = const VerificationMeta(
    'documentJson',
  );
  @override
  late final GeneratedColumn<String> documentJson = GeneratedColumn<String>(
    'document_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    width,
    height,
    fps,
    backgroundKind,
    backgroundColor,
    backgroundImagePath,
    documentJson,
    createdAt,
    updatedAt,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'canvas_projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<CanvasProject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('fps')) {
      context.handle(
        _fpsMeta,
        fps.isAcceptableOrUnknown(data['fps']!, _fpsMeta),
      );
    } else if (isInserting) {
      context.missing(_fpsMeta);
    }
    if (data.containsKey('background_kind')) {
      context.handle(
        _backgroundKindMeta,
        backgroundKind.isAcceptableOrUnknown(
          data['background_kind']!,
          _backgroundKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_backgroundKindMeta);
    }
    if (data.containsKey('background_color')) {
      context.handle(
        _backgroundColorMeta,
        backgroundColor.isAcceptableOrUnknown(
          data['background_color']!,
          _backgroundColorMeta,
        ),
      );
    }
    if (data.containsKey('background_image_path')) {
      context.handle(
        _backgroundImagePathMeta,
        backgroundImagePath.isAcceptableOrUnknown(
          data['background_image_path']!,
          _backgroundImagePathMeta,
        ),
      );
    }
    if (data.containsKey('document_json')) {
      context.handle(
        _documentJsonMeta,
        documentJson.isAcceptableOrUnknown(
          data['document_json']!,
          _documentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_documentJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CanvasProject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CanvasProject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      )!,
      fps: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fps'],
      )!,
      backgroundKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_kind'],
      )!,
      backgroundColor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}background_color'],
      ),
      backgroundImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_image_path'],
      ),
      documentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $CanvasProjectsTable createAlias(String alias) {
    return $CanvasProjectsTable(attachedDatabase, alias);
  }
}

class CanvasProject extends DataClass implements Insertable<CanvasProject> {
  final String id;
  final String title;
  final double width;
  final double height;
  final double fps;
  final String backgroundKind;
  final int? backgroundColor;
  final String? backgroundImagePath;
  final String documentJson;
  final int createdAt;
  final int updatedAt;
  final int version;
  const CanvasProject({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.fps,
    required this.backgroundKind,
    this.backgroundColor,
    this.backgroundImagePath,
    required this.documentJson,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['width'] = Variable<double>(width);
    map['height'] = Variable<double>(height);
    map['fps'] = Variable<double>(fps);
    map['background_kind'] = Variable<String>(backgroundKind);
    if (!nullToAbsent || backgroundColor != null) {
      map['background_color'] = Variable<int>(backgroundColor);
    }
    if (!nullToAbsent || backgroundImagePath != null) {
      map['background_image_path'] = Variable<String>(backgroundImagePath);
    }
    map['document_json'] = Variable<String>(documentJson);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['version'] = Variable<int>(version);
    return map;
  }

  CanvasProjectsCompanion toCompanion(bool nullToAbsent) {
    return CanvasProjectsCompanion(
      id: Value(id),
      title: Value(title),
      width: Value(width),
      height: Value(height),
      fps: Value(fps),
      backgroundKind: Value(backgroundKind),
      backgroundColor: backgroundColor == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundColor),
      backgroundImagePath: backgroundImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundImagePath),
      documentJson: Value(documentJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
    );
  }

  factory CanvasProject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CanvasProject(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      width: serializer.fromJson<double>(json['width']),
      height: serializer.fromJson<double>(json['height']),
      fps: serializer.fromJson<double>(json['fps']),
      backgroundKind: serializer.fromJson<String>(json['backgroundKind']),
      backgroundColor: serializer.fromJson<int?>(json['backgroundColor']),
      backgroundImagePath: serializer.fromJson<String?>(
        json['backgroundImagePath'],
      ),
      documentJson: serializer.fromJson<String>(json['documentJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'width': serializer.toJson<double>(width),
      'height': serializer.toJson<double>(height),
      'fps': serializer.toJson<double>(fps),
      'backgroundKind': serializer.toJson<String>(backgroundKind),
      'backgroundColor': serializer.toJson<int?>(backgroundColor),
      'backgroundImagePath': serializer.toJson<String?>(backgroundImagePath),
      'documentJson': serializer.toJson<String>(documentJson),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int>(version),
    };
  }

  CanvasProject copyWith({
    String? id,
    String? title,
    double? width,
    double? height,
    double? fps,
    String? backgroundKind,
    Value<int?> backgroundColor = const Value.absent(),
    Value<String?> backgroundImagePath = const Value.absent(),
    String? documentJson,
    int? createdAt,
    int? updatedAt,
    int? version,
  }) => CanvasProject(
    id: id ?? this.id,
    title: title ?? this.title,
    width: width ?? this.width,
    height: height ?? this.height,
    fps: fps ?? this.fps,
    backgroundKind: backgroundKind ?? this.backgroundKind,
    backgroundColor: backgroundColor.present
        ? backgroundColor.value
        : this.backgroundColor,
    backgroundImagePath: backgroundImagePath.present
        ? backgroundImagePath.value
        : this.backgroundImagePath,
    documentJson: documentJson ?? this.documentJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
  );
  CanvasProject copyWithCompanion(CanvasProjectsCompanion data) {
    return CanvasProject(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      fps: data.fps.present ? data.fps.value : this.fps,
      backgroundKind: data.backgroundKind.present
          ? data.backgroundKind.value
          : this.backgroundKind,
      backgroundColor: data.backgroundColor.present
          ? data.backgroundColor.value
          : this.backgroundColor,
      backgroundImagePath: data.backgroundImagePath.present
          ? data.backgroundImagePath.value
          : this.backgroundImagePath,
      documentJson: data.documentJson.present
          ? data.documentJson.value
          : this.documentJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CanvasProject(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('fps: $fps, ')
          ..write('backgroundKind: $backgroundKind, ')
          ..write('backgroundColor: $backgroundColor, ')
          ..write('backgroundImagePath: $backgroundImagePath, ')
          ..write('documentJson: $documentJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    width,
    height,
    fps,
    backgroundKind,
    backgroundColor,
    backgroundImagePath,
    documentJson,
    createdAt,
    updatedAt,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CanvasProject &&
          other.id == this.id &&
          other.title == this.title &&
          other.width == this.width &&
          other.height == this.height &&
          other.fps == this.fps &&
          other.backgroundKind == this.backgroundKind &&
          other.backgroundColor == this.backgroundColor &&
          other.backgroundImagePath == this.backgroundImagePath &&
          other.documentJson == this.documentJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version);
}

class CanvasProjectsCompanion extends UpdateCompanion<CanvasProject> {
  final Value<String> id;
  final Value<String> title;
  final Value<double> width;
  final Value<double> height;
  final Value<double> fps;
  final Value<String> backgroundKind;
  final Value<int?> backgroundColor;
  final Value<String?> backgroundImagePath;
  final Value<String> documentJson;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> version;
  final Value<int> rowid;
  const CanvasProjectsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.fps = const Value.absent(),
    this.backgroundKind = const Value.absent(),
    this.backgroundColor = const Value.absent(),
    this.backgroundImagePath = const Value.absent(),
    this.documentJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CanvasProjectsCompanion.insert({
    required String id,
    required String title,
    required double width,
    required double height,
    required double fps,
    required String backgroundKind,
    this.backgroundColor = const Value.absent(),
    this.backgroundImagePath = const Value.absent(),
    required String documentJson,
    required int createdAt,
    required int updatedAt,
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       width = Value(width),
       height = Value(height),
       fps = Value(fps),
       backgroundKind = Value(backgroundKind),
       documentJson = Value(documentJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       version = Value(version);
  static Insertable<CanvasProject> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<double>? width,
    Expression<double>? height,
    Expression<double>? fps,
    Expression<String>? backgroundKind,
    Expression<int>? backgroundColor,
    Expression<String>? backgroundImagePath,
    Expression<String>? documentJson,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fps != null) 'fps': fps,
      if (backgroundKind != null) 'background_kind': backgroundKind,
      if (backgroundColor != null) 'background_color': backgroundColor,
      if (backgroundImagePath != null)
        'background_image_path': backgroundImagePath,
      if (documentJson != null) 'document_json': documentJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CanvasProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<double>? width,
    Value<double>? height,
    Value<double>? fps,
    Value<String>? backgroundKind,
    Value<int?>? backgroundColor,
    Value<String?>? backgroundImagePath,
    Value<String>? documentJson,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return CanvasProjectsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      backgroundKind: backgroundKind ?? this.backgroundKind,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      documentJson: documentJson ?? this.documentJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (fps.present) {
      map['fps'] = Variable<double>(fps.value);
    }
    if (backgroundKind.present) {
      map['background_kind'] = Variable<String>(backgroundKind.value);
    }
    if (backgroundColor.present) {
      map['background_color'] = Variable<int>(backgroundColor.value);
    }
    if (backgroundImagePath.present) {
      map['background_image_path'] = Variable<String>(
        backgroundImagePath.value,
      );
    }
    if (documentJson.present) {
      map['document_json'] = Variable<String>(documentJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CanvasProjectsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('fps: $fps, ')
          ..write('backgroundKind: $backgroundKind, ')
          ..write('backgroundColor: $backgroundColor, ')
          ..write('backgroundImagePath: $backgroundImagePath, ')
          ..write('documentJson: $documentJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppMetadataTable extends AppMetadata
    with TableInfo<$AppMetadataTable, AppMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetadataData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppMetadataTable createAlias(String alias) {
    return $AppMetadataTable(attachedDatabase, alias);
  }
}

class AppMetadataData extends DataClass implements Insertable<AppMetadataData> {
  final String key;
  final String value;
  const AppMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetadataCompanion toCompanion(bool nullToAbsent) {
    return AppMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory AppMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetadataData copyWith({String? key, String? value}) =>
      AppMetadataData(key: key ?? this.key, value: value ?? this.value);
  AppMetadataData copyWithCompanion(AppMetadataCompanion data) {
    return AppMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetadataCompanion extends UpdateCompanion<AppMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CanvasDatabase extends GeneratedDatabase {
  _$CanvasDatabase(QueryExecutor e) : super(e);
  $CanvasDatabaseManager get managers => $CanvasDatabaseManager(this);
  late final $CanvasProjectsTable canvasProjects = $CanvasProjectsTable(this);
  late final $AppMetadataTable appMetadata = $AppMetadataTable(this);
  late final CanvasProjectDao canvasProjectDao = CanvasProjectDao(
    this as CanvasDatabase,
  );
  late final AppMetadataDao appMetadataDao = AppMetadataDao(
    this as CanvasDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    canvasProjects,
    appMetadata,
  ];
}

typedef $$CanvasProjectsTableCreateCompanionBuilder =
    CanvasProjectsCompanion Function({
      required String id,
      required String title,
      required double width,
      required double height,
      required double fps,
      required String backgroundKind,
      Value<int?> backgroundColor,
      Value<String?> backgroundImagePath,
      required String documentJson,
      required int createdAt,
      required int updatedAt,
      required int version,
      Value<int> rowid,
    });
typedef $$CanvasProjectsTableUpdateCompanionBuilder =
    CanvasProjectsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<double> width,
      Value<double> height,
      Value<double> fps,
      Value<String> backgroundKind,
      Value<int?> backgroundColor,
      Value<String?> backgroundImagePath,
      Value<String> documentJson,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> version,
      Value<int> rowid,
    });

class $$CanvasProjectsTableFilterComposer
    extends Composer<_$CanvasDatabase, $CanvasProjectsTable> {
  $$CanvasProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fps => $composableBuilder(
    column: $table.fps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundKind => $composableBuilder(
    column: $table.backgroundKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get backgroundColor => $composableBuilder(
    column: $table.backgroundColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundImagePath => $composableBuilder(
    column: $table.backgroundImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CanvasProjectsTableOrderingComposer
    extends Composer<_$CanvasDatabase, $CanvasProjectsTable> {
  $$CanvasProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fps => $composableBuilder(
    column: $table.fps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundKind => $composableBuilder(
    column: $table.backgroundKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get backgroundColor => $composableBuilder(
    column: $table.backgroundColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundImagePath => $composableBuilder(
    column: $table.backgroundImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CanvasProjectsTableAnnotationComposer
    extends Composer<_$CanvasDatabase, $CanvasProjectsTable> {
  $$CanvasProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<double> get fps =>
      $composableBuilder(column: $table.fps, builder: (column) => column);

  GeneratedColumn<String> get backgroundKind => $composableBuilder(
    column: $table.backgroundKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get backgroundColor => $composableBuilder(
    column: $table.backgroundColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backgroundImagePath => $composableBuilder(
    column: $table.backgroundImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$CanvasProjectsTableTableManager
    extends
        RootTableManager<
          _$CanvasDatabase,
          $CanvasProjectsTable,
          CanvasProject,
          $$CanvasProjectsTableFilterComposer,
          $$CanvasProjectsTableOrderingComposer,
          $$CanvasProjectsTableAnnotationComposer,
          $$CanvasProjectsTableCreateCompanionBuilder,
          $$CanvasProjectsTableUpdateCompanionBuilder,
          (
            CanvasProject,
            BaseReferences<
              _$CanvasDatabase,
              $CanvasProjectsTable,
              CanvasProject
            >,
          ),
          CanvasProject,
          PrefetchHooks Function()
        > {
  $$CanvasProjectsTableTableManager(
    _$CanvasDatabase db,
    $CanvasProjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CanvasProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CanvasProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CanvasProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<double> fps = const Value.absent(),
                Value<String> backgroundKind = const Value.absent(),
                Value<int?> backgroundColor = const Value.absent(),
                Value<String?> backgroundImagePath = const Value.absent(),
                Value<String> documentJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CanvasProjectsCompanion(
                id: id,
                title: title,
                width: width,
                height: height,
                fps: fps,
                backgroundKind: backgroundKind,
                backgroundColor: backgroundColor,
                backgroundImagePath: backgroundImagePath,
                documentJson: documentJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required double width,
                required double height,
                required double fps,
                required String backgroundKind,
                Value<int?> backgroundColor = const Value.absent(),
                Value<String?> backgroundImagePath = const Value.absent(),
                required String documentJson,
                required int createdAt,
                required int updatedAt,
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => CanvasProjectsCompanion.insert(
                id: id,
                title: title,
                width: width,
                height: height,
                fps: fps,
                backgroundKind: backgroundKind,
                backgroundColor: backgroundColor,
                backgroundImagePath: backgroundImagePath,
                documentJson: documentJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CanvasProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$CanvasDatabase,
      $CanvasProjectsTable,
      CanvasProject,
      $$CanvasProjectsTableFilterComposer,
      $$CanvasProjectsTableOrderingComposer,
      $$CanvasProjectsTableAnnotationComposer,
      $$CanvasProjectsTableCreateCompanionBuilder,
      $$CanvasProjectsTableUpdateCompanionBuilder,
      (
        CanvasProject,
        BaseReferences<_$CanvasDatabase, $CanvasProjectsTable, CanvasProject>,
      ),
      CanvasProject,
      PrefetchHooks Function()
    >;
typedef $$AppMetadataTableCreateCompanionBuilder =
    AppMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppMetadataTableUpdateCompanionBuilder =
    AppMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppMetadataTableFilterComposer
    extends Composer<_$CanvasDatabase, $AppMetadataTable> {
  $$AppMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMetadataTableOrderingComposer
    extends Composer<_$CanvasDatabase, $AppMetadataTable> {
  $$AppMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMetadataTableAnnotationComposer
    extends Composer<_$CanvasDatabase, $AppMetadataTable> {
  $$AppMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetadataTableTableManager
    extends
        RootTableManager<
          _$CanvasDatabase,
          $AppMetadataTable,
          AppMetadataData,
          $$AppMetadataTableFilterComposer,
          $$AppMetadataTableOrderingComposer,
          $$AppMetadataTableAnnotationComposer,
          $$AppMetadataTableCreateCompanionBuilder,
          $$AppMetadataTableUpdateCompanionBuilder,
          (
            AppMetadataData,
            BaseReferences<
              _$CanvasDatabase,
              $AppMetadataTable,
              AppMetadataData
            >,
          ),
          AppMetadataData,
          PrefetchHooks Function()
        > {
  $$AppMetadataTableTableManager(_$CanvasDatabase db, $AppMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$CanvasDatabase,
      $AppMetadataTable,
      AppMetadataData,
      $$AppMetadataTableFilterComposer,
      $$AppMetadataTableOrderingComposer,
      $$AppMetadataTableAnnotationComposer,
      $$AppMetadataTableCreateCompanionBuilder,
      $$AppMetadataTableUpdateCompanionBuilder,
      (
        AppMetadataData,
        BaseReferences<_$CanvasDatabase, $AppMetadataTable, AppMetadataData>,
      ),
      AppMetadataData,
      PrefetchHooks Function()
    >;

class $CanvasDatabaseManager {
  final _$CanvasDatabase _db;
  $CanvasDatabaseManager(this._db);
  $$CanvasProjectsTableTableManager get canvasProjects =>
      $$CanvasProjectsTableTableManager(_db, _db.canvasProjects);
  $$AppMetadataTableTableManager get appMetadata =>
      $$AppMetadataTableTableManager(_db, _db.appMetadata);
}
