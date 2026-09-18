import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pinaka_pos/services/CustomerDisplayService.dart';
import 'package:pinaka_pos/services/customer_services.dart';
import 'package:pinaka_pos/services/shift_sync_services.dart';
import 'package:provider/provider.dart';
import 'Blocs/Orders/refund_orderlist_bloc.dart';
import 'Constants/misc_features.dart';
import 'Database/db_helper.dart';
import 'Database/discount_rule_isar.dart';
import 'Database/isar_service.dart';
import 'Database/user_db_helper.dart';
import 'Helper/Extentions/theme_notifier.dart';
import 'Helper/cashbackhelper.dart';
import 'Helper/customerdisplayhelper.dart';
import 'Helper/offline_helper.dart';
import 'Helper/url_helper.dart';
import '../Repositories/Orders/order_repository.dart';

import 'Inventory_screen/Inventory_Tags/inventory_tag_bloc/inventory_tag_bloc.dart';
import 'Inventory_screen/Inventory_Tags/inventory_tag_get_tags_usecase.dart';
import 'Inventory_screen/Inventory_Tags/inventory_tag_remote_data_source.dart';
import 'Inventory_screen/Inventory_Tags/inventory_tag_repository_impl.dart';
import 'Inventory_screen/add_product_toinventory/add_product_inventory_bloc/add_product_inventory_bloc.dart';
import 'Inventory_screen/add_product_toinventory/add_product_inventory_get_usecase.dart';
import 'Inventory_screen/add_product_toinventory/add_product_inventory_remote_data_source.dart';
import 'Inventory_screen/add_product_toinventory/add_product_inventory_repository_impl.dart';
import 'Inventory_screen/inventory_Tax/inventory_tax_bloc/inventory_tax_bloc.dart';
import 'Inventory_screen/inventory_Tax/inventory_tax_get_usecase.dart';
import 'Inventory_screen/inventory_Tax/inventory_tax_remote_data_source.dart';
import 'Inventory_screen/inventory_Tax/inventory_tax_repository_impl.dart';
import 'Inventory_screen/inventory_attribute_items/inventory_attribute_items_bloc/inventory_attribute_items_bloc.dart';
import 'Inventory_screen/inventory_attribute_items/inventory_attribute_items_get_usecase.dart';
import 'Inventory_screen/inventory_attribute_items/inventory_attribute_items_remote_data_source.dart';
import 'Inventory_screen/inventory_attribute_items/inventory_attribute_items_repository_impl.dart';
import 'Inventory_screen/inventory_attributes/inventory_attributes_bloc/inventory_attributes_bloc.dart';
import 'Inventory_screen/inventory_attributes/inventory_attributes_get_usecase.dart';
import 'Inventory_screen/inventory_attributes/inventory_attributes_remote_data_source.dart';
import 'Inventory_screen/inventory_attributes/inventory_attributes_repository_impl.dart';
import 'Inventory_screen/inventory_categories/inventory_categories_bloc/inventory_categories_bloc.dart';
import 'Inventory_screen/inventory_categories/inventory_categories_get_usecase.dart';
import 'Inventory_screen/inventory_categories/inventory_categories_remote_data_source.dart';
import 'Inventory_screen/inventory_categories/inventory_categories_repository_impl.dart';
import 'Inventory_screen/inventory_get_product_types/inventory_get_product_types_bloc/inventory_get_product_types_bloc.dart';
import 'Inventory_screen/inventory_get_product_types/inventory_get_product_types_get_usecase.dart';
import 'Inventory_screen/inventory_get_product_types/inventory_get_product_types_remote_data_source.dart';
import 'Inventory_screen/inventory_get_product_types/inventory_get_product_types_repository_impl.dart';
import 'Preferences/pinaka_preferences.dart';
import 'Repositories/Orders/refund_orderlist_repository.dart';
import 'Screens/Auth/splash_screen.dart';
import 'package:flutter/services.dart';
import '../../Helper/api_helper.dart';

import 'Widgets/discount_engine_constants.dart';
import 'Widgets/navigation_services.dart';
import 'Widgets/offline_order_sync_service.dart';
import 'Widgets/weighing_scale_widget.dart';
import 'Utilities/global_utility.dart';
import 'mqtt_server/cart_provider.dart';
import 'mqtt_server/cart_state.dart';
import 'mqtt_server/cfd_store_payload.dart';
import 'mqtt_server/store_messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT FOR PLAY / PRE-LAUNCH:
  // Only local, deterministic initialization is allowed before runApp().
  // Network, MQTT, mDNS, customer-display and cashback services must never
  // prevent Flutter from rendering the first screen.
  try {
    await IsarService.init().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('[Startup] Isar init skipped: $e');
  }

  try {
    AppDB.isar = await Isar.open(
      [DiscountRuleIsarSchema],
      directory: (await getApplicationDocumentsDirectory()).path,
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('[Startup] Discount-rule Isar init skipped: $e');
  }

  try {
    await UrlHelper.initializeBaseUrl().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('[Startup] Base URL initialization failed: $e');
  }

  try {
    await PinakaPreferences.prepareSharedPref().timeout(
      const Duration(seconds: 3),
    );
  } catch (e) {
    debugPrint('[Startup] SharedPreferences initialization failed: $e');
    // The app cannot safely construct ThemeNotifier/other preference users
    // without SharedPreferences, so retry once locally before giving up.
    try {
      await PinakaPreferences.prepareSharedPref().timeout(
        const Duration(seconds: 3),
      );
    } catch (retryError) {
      debugPrint('[Startup] SharedPreferences retry failed: $retryError');
    }
  }

  final themeNotifier = ThemeNotifier();
  try {
    await themeNotifier.initializeThemeMode().timeout(
      const Duration(seconds: 2),
    );
  } catch (e) {
    debugPrint('[Startup] Theme initialization skipped: $e');
  }

  if (!Misc.enableHardwareBackButton) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [],
    );
  }

  // Local database initialization only. Never contact the merchant server here.
  try {
    await DBHelper.instance.database.timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('[Startup] Local SQLite initialization failed: $e');
  }

  try {
    await OfflineHelper.restoreStoredCurrency().timeout(
      const Duration(seconds: 2),
    );
  } catch (e) {
    debugPrint('[Startup] Currency restore skipped: $e');
  }

  final httpClient = http.Client();

  final inventoryTagRemoteDataSource =
      Inventory_Tag_Remote_Data_Source_Impl(httpClient);
  final inventoryTagRepository =
      Inventory_Tag_Repository_Impl(inventoryTagRemoteDataSource);
  final inventoryTagUseCase =
      Inventory_Tag_Get_Tags_UseCase(inventoryTagRepository);

  final inventoryTaxRemoteDataSource =
      Inventory_Tax_Remote_Data_Source_Impl(httpClient);
  final inventoryTaxRepository =
      Inventory_Tax_Repository_Impl(inventoryTaxRemoteDataSource);
  final inventoryTaxUseCase =
      Inventory_Tax_Get_UseCase(inventoryTaxRepository);

  final inventoryCategoriesRemoteDataSource =
      InventoryCategoriesRemoteDataSourceImpl(client: httpClient);
  final inventoryCategoriesRepository =
      InventoryCategoriesRepositoryImpl(
    remoteDataSource: inventoryCategoriesRemoteDataSource,
  );
  final inventoryCategoriesUseCase =
      InventoryCategoriesGetUseCase(
    repository: inventoryCategoriesRepository,
  );

  final inventoryAttributesRemoteDataSource =
      InventoryAttributesRemoteDataSourceImpl(client: httpClient);
  final inventoryAttributesRepository =
      InventoryAttributesRepositoryImpl(
    remoteDataSource: inventoryAttributesRemoteDataSource,
  );
  final inventoryAttributesUseCase =
      InventoryAttributesGetUseCase(
    repository: inventoryAttributesRepository,
  );

  final inventoryProductTypesRemoteDataSource =
      InventoryGetProductTypesRemoteDataSourceImpl(client: httpClient);
  final inventoryProductTypesRepository =
      InventoryGetProductTypesRepositoryImpl(
    remoteDataSource: inventoryProductTypesRemoteDataSource,
  );
  final inventoryProductTypesUseCase =
      InventoryGetProductTypesGetUseCase(
    repository: inventoryProductTypesRepository,
  );

  final addProductRemoteDataSource =
      AddProductInventoryTaxRemoteDataSource();
  final addProductRepository =
      AddProductInventoryTaxRepositoryImpl(
    remoteDataSource: addProductRemoteDataSource,
  );
  final addProductUseCase =
      AddProductInventoryTaxGetUseCase(
    repository: addProductRepository,
  );
  final addProductBloc =
      AddProductInventoryTaxBloc(addProductUseCase: addProductUseCase);

  // Construct the messaging service, but DO NOT start network services yet.
  final messagingService = StoreMessagingService(
    merchantId: 'M1001',
    storeId: 'S001',
    terminalId: 'POS01',
    brokerUsername: 'pinaka_cfd',
    brokerToken: 'generated-device-token',
  );

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CompletedOrdersRepository>(
          create: (_) => CompletedOrdersRepository(
            baseUrl: "https://merchantretail.alektasolutions.com",
          ),
        ),
        RepositoryProvider<StoreMessagingService>.value(
          value: messagingService,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<CompletedOrdersBloc>(
            create: (context) => CompletedOrdersBloc(
              context.read<CompletedOrdersRepository>(),
            ),
          ),
          BlocProvider<Inventory_Tag_Bloc>(
            create: (_) => Inventory_Tag_Bloc(inventoryTagUseCase),
          ),
          BlocProvider<Inventory_Tax_Bloc>(
            create: (_) => Inventory_Tax_Bloc(inventoryTaxUseCase),
          ),
          BlocProvider<InventoryCategoriesBloc>(
            create: (_) => InventoryCategoriesBloc(
              getCategoriesUseCase: inventoryCategoriesUseCase,
            ),
          ),
          BlocProvider<InventoryAttributesBloc>(
            create: (_) => InventoryAttributesBloc(
              getUseCase: inventoryAttributesUseCase,
            ),
          ),
          BlocProvider<InventoryGetProductTypesBloc>(
            create: (_) => InventoryGetProductTypesBloc(
              useCase: inventoryProductTypesUseCase,
            ),
          ),
          BlocProvider<AddProductInventoryTaxBloc>(
            create: (_) => addProductBloc,
          ),
          ChangeNotifierProvider(create: (_) => WeightProvider()),
          ChangeNotifierProvider(
            create: (_) => CartProvider(
              messagingService: messagingService,
              sessionId:
                  'SALE-${DateTime.now().millisecondsSinceEpoch}',
            ),
          ),
        ],
        child: ChangeNotifierProvider(
          create: (_) => themeNotifier,
          child: const MyApp(),
        ),
      ),
    ),
  );

  // Everything below is intentionally post-first-frame. If the Google
  // pre-launch device has no Internet, no DNS, no LAN, no secondary display,
  // or no MQTT broker, the POS UI still reaches SplashScreen/LoginScreen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_startNonCriticalServices(messagingService, httpClient));
  });
}

Future<void> _startNonCriticalServices(
  StoreMessagingService messagingService,
  http.Client httpClient,
) async {
  // Keep the connectivity/sync listeners alive, but never await network work
  // before the first UI frame.
  try {
    ShiftSyncService().startListening();
  } catch (e) {
    debugPrint('[Startup] Shift sync listener failed: $e');
  }

  try {
    final userData = await UserDbHelper().getUserData().timeout(
      const Duration(seconds: 2),
    );
    final token = userData?[AppDBConst.userToken];
    if (token != null && token.toString().isNotEmpty) {
      await CashbackHelper.loadCashbackOnStartup().timeout(
        const Duration(seconds: 4),
      );
    }
  } catch (e) {
    debugPrint('[Startup] Cashback startup skipped: $e');
  }

  try {
    OfflineOrderSyncService.start();
  } catch (e) {
    debugPrint('[Startup] Offline order sync startup failed: $e');
  }

  final storeInfo = PinakaPreferences.getLoggedInStore();

  // Secondary display is optional. Never block the POS if it is unavailable.
  try {
    if (storeInfo.isNotEmpty) {
      await CustomerDisplayHelper.updateWelcomeWithStore(
        storeInfo['storeId'] ?? '',
        storeInfo['storeName'] ?? '',
        storeLogoUrl: storeInfo['storeLogoUrl'],
        storeBaseUrl: storeInfo['storeBaseUrl'],
      ).timeout(const Duration(seconds: 2));
    } else {
      await CustomerDisplayService.showWelcome().timeout(
        const Duration(seconds: 2),
      );
    }
  } catch (e) {
    debugPrint('[Startup] Customer display startup skipped: $e');
  }

  // MQTT / mDNS are optional POS-to-CFD features. None of these calls may
  // prevent the Flutter application from being rendered.
  try {
    await messagingService.startBroker().timeout(
      const Duration(seconds: 3),
    );
  } catch (e) {
    debugPrint('[Startup] MQTT broker startup skipped: $e');
  }

  try {
    await messagingService.startPublisher().timeout(
      const Duration(seconds: 3),
    );
  } catch (e) {
    debugPrint('[Startup] MQTT publisher startup skipped: $e');
  }

  try {
    await messagingService.startMdnsAdvertisement().timeout(
      const Duration(seconds: 3),
    );
  } catch (e) {
    debugPrint('[Startup] mDNS startup skipped: $e');
  }

  try {
    final posIp = await messagingService.getDeviceLocalIp().timeout(
      const Duration(seconds: 2),
    );
    if (posIp != null && posIp.isNotEmpty) {
      debugPrint('[Startup] POS DEVICE IP: $posIp');
    }
  } catch (e) {
    debugPrint('[Startup] Local IP detection skipped: $e');
  }

  try {
    final store = await CfdStorePayload.load().timeout(
      const Duration(seconds: 3),
    );
    await messagingService.publishState(
      CartState(
        sessionId: 'WELCOME',
        sequence: 0,
        screen: 'WELCOME',
        items: const [],
        storeId: store.storeId,
        storeName: store.storeName,
        storeLogoUrl: store.storeLogoUrl,
        storeBaseUrl: store.storeBaseUrl,
        slideshowUrls: store.slideshowUrls,
      ),
    ).timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('[Startup] MQTT welcome publish skipped: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return SafeArea(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeNotifier.lightTheme.copyWith(
          textTheme: GoogleFonts.interTextTheme(ThemeNotifier.lightTheme.textTheme),
        ),
        darkTheme: ThemeNotifier.darkTheme.copyWith(
          textTheme: GoogleFonts.interTextTheme(ThemeNotifier.darkTheme.textTheme),
        ),
        themeMode: themeHelper.themeMode,
        builder: (context, child) {
          final scale = MediaQuery.of(context)
              .textScaler
              .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.0);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scale),
            child: child!,
          );
        },
        home: PopScope(
          canPop: Misc.enableHardwareBackButton,
          child: Scaffold(
            body: SplashScreen(),
          ),
        ),
      ),
    );
  }
}


//
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:isar/isar.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:pinaka_pos/services/CustomerDisplayService.dart';
// import 'package:provider/provider.dart';
// import 'Constants/misc_features.dart';
// import 'Database/db_helper.dart';
// import 'Database/discount_rule_isar.dart';
// import 'Database/isar_service.dart';
// import 'Database/user_db_helper.dart';
// import 'Helper/Extentions/theme_notifier.dart';
// import 'Helper/cashbackhelper.dart';
// import 'Helper/customerdisplayhelper.dart';
// import 'Helper/url_helper.dart';
// import '../Repositories/Orders/order_repository.dart';
//
// import 'Inventory_screen/Inventory_Tags/inventory_tag_bloc/inventory_tag_bloc.dart';
// import 'Inventory_screen/Inventory_Tags/inventory_tag_get_tags_usecase.dart';
// import 'Inventory_screen/Inventory_Tags/inventory_tag_remote_data_source.dart';
// import 'Inventory_screen/Inventory_Tags/inventory_tag_repository_impl.dart';
// import 'Inventory_screen/add_product_toinventory/add_product_inventory_bloc/add_product_inventory_bloc.dart';
// import 'Inventory_screen/add_product_toinventory/add_product_inventory_get_usecase.dart';
// import 'Inventory_screen/add_product_toinventory/add_product_inventory_remote_data_source.dart';
// import 'Inventory_screen/add_product_toinventory/add_product_inventory_repository_impl.dart';
// import 'Inventory_screen/inventory_Tax/inventory_tax_bloc/inventory_tax_bloc.dart';
// import 'Inventory_screen/inventory_Tax/inventory_tax_get_usecase.dart';
// import 'Inventory_screen/inventory_Tax/inventory_tax_remote_data_source.dart';
// import 'Inventory_screen/inventory_Tax/inventory_tax_repository_impl.dart';
// import 'Inventory_screen/inventory_attribute_items/inventory_attribute_items_bloc/inventory_attribute_items_bloc.dart';
// import 'Inventory_screen/inventory_attribute_items/inventory_attribute_items_get_usecase.dart';
// import 'Inventory_screen/inventory_attribute_items/inventory_attribute_items_remote_data_source.dart';
// import 'Inventory_screen/inventory_attribute_items/inventory_attribute_items_repository_impl.dart';
// import 'Inventory_screen/inventory_attributes/inventory_attributes_bloc/inventory_attributes_bloc.dart';
// import 'Inventory_screen/inventory_attributes/inventory_attributes_get_usecase.dart';
// import 'Inventory_screen/inventory_attributes/inventory_attributes_remote_data_source.dart';
// import 'Inventory_screen/inventory_attributes/inventory_attributes_repository_impl.dart';
// import 'Inventory_screen/inventory_categories/inventory_categories_bloc/inventory_categories_bloc.dart';
// import 'Inventory_screen/inventory_categories/inventory_categories_get_usecase.dart';
// import 'Inventory_screen/inventory_categories/inventory_categories_remote_data_source.dart';
// import 'Inventory_screen/inventory_categories/inventory_categories_repository_impl.dart';
// import 'Inventory_screen/inventory_get_product_types/inventory_get_product_types_bloc/inventory_get_product_types_bloc.dart';
// import 'Inventory_screen/inventory_get_product_types/inventory_get_product_types_get_usecase.dart';
// import 'Inventory_screen/inventory_get_product_types/inventory_get_product_types_remote_data_source.dart';
// import 'Inventory_screen/inventory_get_product_types/inventory_get_product_types_repository_impl.dart';
// import 'Preferences/pinaka_preferences.dart';
// import 'Repositories/Orders/refund_orderlist_repository.dart';
// import 'Screens/Auth/splash_screen.dart';
// import 'package:flutter/services.dart';
// import '../../Helper/api_helper.dart';
//
// import 'Widgets/discount_engine_constants.dart';
// import 'Widgets/offline_order_sync_service.dart';
// import 'Widgets/weighing_scale_widget.dart';
//
// void main() async {
//
//   WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter services are ready
//
//   // Initialize Isar first
//   await IsarService.init();
//
//   AppDB.isar = await Isar.open(
//     [DiscountRuleIsarSchema],
//     directory: (await getApplicationDocumentsDirectory()).path,
//   );
//
//
//   // 1️⃣ First → initialize base URL
//   await UrlHelper.initializeBaseUrl();
//
//   // 2️⃣ Then prepare shared preferences
//   await PinakaPreferences.prepareSharedPref();
//
//   // 3️⃣ Then load cashback config
//   final userData = await UserDbHelper().getUserData();
//   final token = userData?[AppDBConst.userToken];
//
//   if (token != null && token.toString().isNotEmpty) {
//     await CashbackHelper.loadCashbackOnStartup();
//   } else {
//     print("⚠ No user token found — skipping cashback API");
//   }
//   /// Build #1.0.187: Required -> Disable device back button completely
//   /// This block locks the app to hides system overlays (e.g., status bar, navigation bar) if enableHardwareBackButton is false
//   if (!Misc.enableHardwareBackButton) {
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
//   }
//
//   ThemeNotifier themeNotifier = ThemeNotifier();
//   await themeNotifier.initializeThemeMode();
//   // Build #1.0.9 : By default dark theme getting selected on launch even after changing from settings
//   await UrlHelper.initializeBaseUrl();
//   await DBHelper.instance.database;
//   final storeInfo = PinakaPreferences.getLoggedInStore();
//   if (storeInfo.isNotEmpty) {
//     await CustomerDisplayHelper.updateWelcomeWithStore(
//       storeInfo['storeId']!,
//       storeInfo['storeName']!,
//       storeLogoUrl: storeInfo['storeLogoUrl'],
//       storeBaseUrl: storeInfo['storeBaseUrl'],
//     );
//   } else {
//     await CustomerDisplayService.showWelcome();
//   }
//
//   /////Inventory_Tag_Get
//   final httpClient = http.Client();
//
//   final inventoryTagRemoteDataSource = Inventory_Tag_Remote_Data_Source_Impl(httpClient);
//
//   final inventoryTagRepository = Inventory_Tag_Repository_Impl(inventoryTagRemoteDataSource);
//
//   final inventoryTagUseCase = Inventory_Tag_Get_Tags_UseCase(inventoryTagRepository);
//
// //////Inventory_Tax_Get
//
//   final inventoryTaxRemoteDataSource = Inventory_Tax_Remote_Data_Source_Impl(httpClient);
//
//   final inventoryTaxRepository = Inventory_Tax_Repository_Impl(inventoryTaxRemoteDataSource);
//
//   final inventoryTaxUseCase = Inventory_Tax_Get_UseCase(inventoryTaxRepository);
//
//   // Inventory Categories
//   final inventoryCategoriesRemoteDataSource = InventoryCategoriesRemoteDataSourceImpl(client: httpClient);
//   final inventoryCategoriesRepository = InventoryCategoriesRepositoryImpl(remoteDataSource: inventoryCategoriesRemoteDataSource);
//   final inventoryCategoriesUseCase = InventoryCategoriesGetUseCase(repository: inventoryCategoriesRepository);
//
//   // Inventory Attributes
//   final inventoryAttributesRemoteDataSource = InventoryAttributesRemoteDataSourceImpl(client: httpClient);
//   final inventoryAttributesRepository = InventoryAttributesRepositoryImpl(remoteDataSource: inventoryAttributesRemoteDataSource);
//   final inventoryAttributesUseCase = InventoryAttributesGetUseCase(repository: inventoryAttributesRepository);
//
//
//   //  InventoryGetProductTypes setup
//   final inventoryProductTypesRemoteDataSource = InventoryGetProductTypesRemoteDataSourceImpl(client: httpClient);
//   final inventoryProductTypesRepository = InventoryGetProductTypesRepositoryImpl(remoteDataSource: inventoryProductTypesRemoteDataSource);
//   final inventoryProductTypesUseCase = InventoryGetProductTypesGetUseCase(repository: inventoryProductTypesRepository);
//
//   //  Create the remote data source
// //   final inventoryAttributeItemsRemoteDataSource =
// //   InventoryAttributeItemsRemoteDataSourceImpl(
// //     client: http.Client(),
// //   );
// //
// // // Create the repository and inject the remote data source
// //   final inventoryAttributeItemsRepository = InventoryAttributeItemsRepositoryImpl(
// //     remoteDataSource: inventoryAttributeItemsRemoteDataSource,
// //   );
//
// //  Create the use case and inject the repository
// //   final inventoryAttributeItemsUseCase = GetInventoryAttributeItemsUseCase(
// //     repository: inventoryAttributeItemsRepository,
// //   );
//
//   // Add Product WooCommerce setup
//
//   final addProductRemoteDataSource = AddProductInventoryTaxRemoteDataSource();
//   final addProductRepository = AddProductInventoryTaxRepositoryImpl(remoteDataSource: addProductRemoteDataSource);
//   final addProductUseCase = AddProductInventoryTaxGetUseCase(repository: addProductRepository);
//   final addProductBloc = AddProductInventoryTaxBloc(addProductUseCase: addProductUseCase);
//
//
//   // runApp(
//   //   ChangeNotifierProvider(
//   //     create: (_) => themeNotifier,
//   //     child: const MyApp(),
//   //   ),
//   // );
//
//
//   runApp(
//       MultiRepositoryProvider(
//         providers: [
//           RepositoryProvider<CompletedOrdersRepository>(
//             create: (_) => CompletedOrdersRepository(
//               baseUrl: "https://merchantretail.alektasolutions.com", token: '',
//
//             ),
//           ),
//         ],
//         child:
//         MultiBlocProvider(
//           providers: [
//             BlocProvider<Inventory_Tag_Bloc>(
//               create: (_) => Inventory_Tag_Bloc(inventoryTagUseCase),
//             ),
//
//             BlocProvider<Inventory_Tax_Bloc>(
//               create: (_) => Inventory_Tax_Bloc(inventoryTaxUseCase),
//             ),
//
//             BlocProvider<InventoryCategoriesBloc>(
//               create: (_) => InventoryCategoriesBloc(getCategoriesUseCase: inventoryCategoriesUseCase),
//             ),
//
//             BlocProvider<InventoryAttributesBloc>(
//               create: (_) => InventoryAttributesBloc(getUseCase: inventoryAttributesUseCase),
//             ),
//             BlocProvider<InventoryGetProductTypesBloc>(
//               create: (_) =>
//                   InventoryGetProductTypesBloc(useCase: inventoryProductTypesUseCase),
//             ),
//
//             // BlocProvider<InventoryAttributeItemsBloc>(
//             //   create: (_) => InventoryAttributeItemsBloc(getItemsUseCase: inventoryAttributeItemsUseCase),
//             // ),
//
//
//             // Add Product Bloc
//             BlocProvider<AddProductInventoryTaxBloc>(create: (_) => addProductBloc),
//             //ChangeNotifierProvider(create: (_) => WeightProvider())
//             ChangeNotifierProvider(create: (_) => WeightProvider())
//
//
//
//           ],
//           child: ChangeNotifierProvider(
//             create: (_) => themeNotifier,
//             child: const MyApp(),
//           ),
//         ),
//       ));
//
// }
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     return SafeArea(  //Build #1.0.2 : Fixed - status bar overlapping with design
//       child: MaterialApp(
//         debugShowCheckedModeBanner: false,
//         theme: ThemeNotifier.lightTheme.copyWith(
//           // Add Poppins to your existing light theme
//           textTheme: GoogleFonts.interTextTheme(ThemeNotifier.lightTheme.textTheme),
//         ),
//         darkTheme: ThemeNotifier.darkTheme.copyWith(
//           // Add Poppins to your existing dark theme
//           textTheme: GoogleFonts.interTextTheme(ThemeNotifier.darkTheme.textTheme),
//         ),
//         themeMode: themeHelper.themeMode,
//         builder: (context, child) {
//           // Widget error = const Text('...rendering error...');
//
//           // final scale = MediaQuery.of(context).textScaleFactor.clamp(0.9, 1.0);
//           final scale = MediaQuery.of(context)
//               .textScaler
//               .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.0);
//           return MediaQuery(
//             // data: MediaQuery.of(context).copyWith(textScaleFactor: scale ), child: child!, //set desired text scale factor here
//             data: MediaQuery.of(context).copyWith(textScaler: scale),
//             child: child!, //set desired text scale factor here
//           );
//         },
//         home: PopScope( // Build #1.0.187: Fixed - prevents back navigation / hardware back button
//           canPop: Misc.enableHardwareBackButton, // Build #1.0.189: Added misc boolean value for enable/disable device back button
//           child: Scaffold(
//             body: SplashScreen(),
//           ),
//         ),
//       ),
//     );
//   }
// }