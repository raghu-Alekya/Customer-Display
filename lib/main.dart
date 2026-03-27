import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keyos_app/repository/category_data_resource.dart';
import 'package:keyos_app/repository/product_data_resource.dart';
import 'package:keyos_app/repository/user_login_repository.dart';

import 'bloc/category_bloc.dart';
import 'bloc/product_bloc.dart';
import 'bloc/sub category_bloc.dart';
import 'login_screen.dart';
import 'bloc/user_login_bloc.dart';
// import 'repository/auth_repository.dart'; // make sure path is correct

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(AuthRepository()),
        ),
        BlocProvider(
          create: (_) => CategoryBloc(repository: CategoryRepository())
            ..add(const FetchCategories()),
        ),
        BlocProvider(
          create: (_) => ProductBloc(repository: ProductRepository()),
        ),
        BlocProvider(
          create: (_) => SubcategoryBloc(repository: CategoryRepository()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'My App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}