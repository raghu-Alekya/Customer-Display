
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:kiosk/repository/category_data_resource.dart';
import 'package:kiosk/repository/product_data_resource.dart';
import 'package:kiosk/repository/user_login_repository.dart';
import 'package:kiosk/repository/promotion_repository.dart';
import 'package:kiosk/repository/store_details_repository.dart';
import 'package:kiosk/widgets/kiosk_frame.dart';

import 'bloc/category_bloc.dart';
import 'bloc/product_bloc.dart';
import 'bloc/promotion_bloc.dart';
import 'bloc/store_details_bloc.dart';
import 'bloc/sub category_bloc.dart';
import 'login_screen.dart';
import 'bloc/user_login_bloc.dart';
import 'splashscreen.dart';
// import 'repository/auth_repository.dart'; // make sure path is correct

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );
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
        BlocProvider(
          create: (_) => PromotionBloc(repository: PromotionRepository()),
        ),
        BlocProvider(
          create: (_) =>
              StoreDetailsBloc(repository: StoreDetailsRepository()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'My App',
        // No global button themes: each ElevatedButton / TextButton / OutlinedButton
        // keeps its own backgroundColor / foregroundColor, and hover/splash follow that.
        theme: ThemeData(
          useMaterial3: true,
          primarySwatch: Colors.orange,
        ),
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          return child; // no KioskFrame, use full screen dynamically
        },
        home: const LoginScreen(),
      ),
    );
  }
}
