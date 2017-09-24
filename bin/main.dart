// Copyright (c) 2017, teja. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library many_to_many;

import 'dart:io';
import 'dart:async';
import 'package:jaguar_query/jaguar_query.dart';
import 'package:jaguar_orm/jaguar_orm.dart';
import 'package:jaguar_query_postgresql/jaguar_query_postgresql.dart';

part 'main.g.dart';

class Category {
  @PrimaryKey()
  String id;

  String name;

  @ManyToMany(PivotBean, TodoListBean)
  List<TodoList> todolists;

  static const String tableName = 'category';

  String toString() => "Category($id, $name, $todolists)";
}

class TodoList {
  @PrimaryKey()
  String id;

  String description;

  @ManyToMany(PivotBean, CategoryBean)
  List<Category> categories;

  static String tableName = 'todolist';

  String toString() => "Post($id, $description, $categories)";
}

class Pivot {
  @BelongsToMany(TodoListBean)
  String todolist_id;

  @BelongsToMany(CategoryBean)
  String category_id;

  static String tableName = 'pivot';
}

@GenBean()
class TodoListBean extends Bean<TodoList> with _TodoListBean {
  PivotBean _pivotBean;

  CategoryBean _categoryBean;

  TodoListBean(Adapter adapter) : super(adapter);

  PivotBean get pivotBean {
    _pivotBean ??= new PivotBean(adapter);
    return _pivotBean;
  }

  CategoryBean get categoryBean {
    _categoryBean ??= new CategoryBean(adapter);
    return _categoryBean;
  }

  Future createTable() {
    final st = Sql
        .create(tableName)
        .addStr('id', primary: true, length: 50)
        .addStr('description', length: 50);
    return execCreateTable(st);
  }
}

@GenBean()
class CategoryBean extends Bean<Category> with _CategoryBean {
  final PivotBean pivotBean;

  final TodoListBean todoListBean;

  CategoryBean(Adapter adapter)
      : pivotBean = new PivotBean(adapter),
        todoListBean = new TodoListBean(adapter),
        super(adapter);

  Future createTable() {
    final st = Sql
        .create(tableName)
        .addStr('id', primary: true, length: 50)
        .addStr('name', length: 150);
    return execCreateTable(st);
  }
}

@GenBean()
class PivotBean extends Bean<Pivot> with _PivotBean {
  CategoryBean _categoryBean;

  TodoListBean _todoListBean;

  PivotBean(Adapter adapter) : super(adapter);

  CategoryBean get categoryBean {
    _categoryBean ??= new CategoryBean(adapter);
    return _categoryBean;
  }

  TodoListBean get todoListBean {
    _todoListBean ??= new TodoListBean(adapter);
    return _todoListBean;
  }

  Future createTable() {
    final st = Sql
        .create(tableName)
        .addStr('todolist_id',
            length: 50, foreignTable: TodoList.tableName, foreignCol: 'id')
        .addStr('category_id',
            length: 50, foreignTable: Category.tableName, foreignCol: 'id');
    return execCreateTable(st);
  }
}

/// The adapter
PgAdapter _adapter =
    new PgAdapter('postgres://postgres:dart_jaguar@localhost/example');

main() async {
  // Connect to database
  await _adapter.connect();

  // Create beans
  final todolistBean = new TodoListBean(_adapter);
  final categoryBean = new CategoryBean(_adapter);
  final pivotBean = new PivotBean(_adapter);

  // Drop old tables
  await pivotBean.drop();
  await categoryBean.drop();
  await todolistBean.drop();

  // Create new tables
  await todolistBean.createTable();
  await categoryBean.createTable();
  await pivotBean.createTable();

  // Cascaded Many-To-Many insert
  {
    final todolist = new TodoList()
      ..id = '1'
      ..description = 'List 1'
      ..categories = <Category>[
        new Category()
          ..id = '10'
          ..name = 'Cat 10',
        new Category()
          ..id = '11'
          ..name = 'Cat 11'
      ];
    await todolistBean.insert(todolist, cascade: true);
  }

  // Fetch Many-To-Many preloaded
  {
    final todolist = await todolistBean.find('1', preload: true);
    print(todolist);
  }

  // Manual Many-To-Many insert
  {
    TodoList todolist = new TodoList()
      ..id = '2'
      ..description = 'List 2';
    await todolistBean.insert(todolist, cascade: true);

    todolist = await todolistBean.find('2');

    final category1 = new Category()
      ..id = '20'
      ..name = 'Cat 20';
    await categoryBean.insert(category1);
    await pivotBean.attach(todolist, category1);

    final category2 = new Category()
      ..id = '21'
      ..name = 'Cat 21';
    await categoryBean.insert(category2);
    await pivotBean.attach(todolist, category2);
  }

  // Manual Many-To-Many preload
  {
    final todolist = await todolistBean.find('2');
    print(todolist);
    todolist.categories = await pivotBean.fetchByTodoList(todolist);
    print(todolist);
  }

  // TODO preload many

  // Cascaded Many-To-Many update
  {
    TodoList todolist = await todolistBean.find('1', preload: true);
    todolist.description += '!';
    todolist.categories[0].name += '!';
    todolist.categories[1].name += '!';
    await todolistBean.update(todolist, cascade: true);
  }

  // Debug print out
  {
    final user = await todolistBean.find('1', preload: true);
    print(user);
  }

  // Cascaded removal of Many-To-Many relation
  await todolistBean.remove('1', true);

  // Debug print out
  {
    final user = await todolistBean.getAll();
    print(user);
    final categories = await categoryBean.getAll();
    print(categories);
  }

  exit(0);
}
