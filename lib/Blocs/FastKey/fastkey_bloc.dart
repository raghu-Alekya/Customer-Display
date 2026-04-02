import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Helper/api_response.dart';
import '../../Models/FastKey/fastkey_model.dart';
import '../../Models/FastKey/fastkey_product_model.dart';
import '../../Repositories/FastKey/fastkey_repository.dart';
import '../../Database/fast_key_db_helper.dart';
import '../../Database/db_helper.dart';
import '../../Utilities/global_utility.dart';

class FastKeyBloc { // Build #1.0.15
  final FastKeyRepository _fastKeyRepository;

  // Stream Controllers
  final StreamController<APIResponse<FastKeyResponse>> _createFastKeyController =
  StreamController<APIResponse<FastKeyResponse>>.broadcast();

  final StreamController<APIResponse<FastKeyListResponse>> _getFastKeysController =
  StreamController<APIResponse<FastKeyListResponse>>.broadcast();

  // Getters for Streams
  StreamSink<APIResponse<FastKeyResponse>> get createFastKeySink => _createFastKeyController.sink;
  Stream<APIResponse<FastKeyResponse>> get createFastKeyStream => _createFastKeyController.stream;

  StreamSink<APIResponse<FastKeyListResponse>> get getFastKeysSink => _getFastKeysController.sink;
  Stream<APIResponse<FastKeyListResponse>> get getFastKeysStream => _getFastKeysController.stream;

  // Build #1.0.19: Fast Key Delete API Code
  final StreamController<APIResponse<FastKeyResponse>> _deleteFastKeyController =
  StreamController<APIResponse<FastKeyResponse>>.broadcast();

  StreamSink<APIResponse<FastKeyResponse>> get deleteFastKeySink => _deleteFastKeyController.sink;
  Stream<APIResponse<FastKeyResponse>> get deleteFastKeyStream => _deleteFastKeyController.stream;

  // Build #1.0.89: Added StreamController for updateFastKey
  final StreamController<APIResponse<FastKeyResponse>> _updateFastKeyController =
  StreamController<APIResponse<FastKeyResponse>>.broadcast();

  StreamSink<APIResponse<FastKeyResponse>> get updateFastKeySink => _updateFastKeyController.sink;
  Stream<APIResponse<FastKeyResponse>> get updateFastKeyStream => _updateFastKeyController.stream;

  FastKeyBloc(this._fastKeyRepository) {
    if (kDebugMode) {
      print("FastKeyBloc Initialized");
    }
  }

  // POST: Create FastKey
  Future<void> createFastKey({required String title, required int index, required String imageUrl, required int userId}) async {
    if (_createFastKeyController.isClosed) return;

    createFastKeySink.add(APIResponse.loading(TextConstants.loading));
    try {
      final request = FastKeyRequest(
        fastkeyTitle: title,
        fastkeyIndex: index,
        fastkeyImage: imageUrl,
        userId: userId,
      );

      final response = await _fastKeyRepository.createFastKey(request);

      if (kDebugMode) {
        print("FastKeyBloc - Created FastKey: ${response.fastkeyId}");
      }
      // Build #1.0.87: Insert into DB after successful API response
      final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
      final newTabId = await fastKeyDBHelper.addFastKeyTab(
        userId,
        response.fastkeyTitle,
        response.fastkeyImage,
        0,
        int.parse(response.fastkeyIndex),
        response.fastkeyId,
      );
      if (kDebugMode) {
        print("### FastKeyBloc: Added tab to DB with local ID: $newTabId, server ID: ${response.fastkeyId}");
      }
      await fastKeyDBHelper.saveActiveFastKeyTab(response.fastkeyId);
      if (kDebugMode) {
        print("### FastKeyBloc: Saved active tab ID: ${response.fastkeyId}");
      }
      createFastKeySink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        createFastKeySink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else {
        createFastKeySink.add(
            APIResponse.error(GlobalUtility.extractErrorMessage(e)));
      }//Build #1.0.189: Proper error not showing while getting error in create fast key
      if (kDebugMode) print("Exception in createFastKey: $e");
    }
  }

  // GET: Fetch FastKeys by User
  Future<void> fetchFastKeysByUser(int userId) async {
    if (_getFastKeysController.isClosed) return;

    getFastKeysSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final response = await _fastKeyRepository.getFastKeysByUser();

      if (kDebugMode) {
        print("FastKeyBloc - Fetched ${response.fastkeys.length} fastkeys");
        print("Response: ${response}");
      }

      ///insert into DB

      final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
      final fastKeyTabs = await fastKeyDBHelper.getFastKeyTabsByUserId(userId ?? 0);
      if (kDebugMode) {
        print("#### fastKeyTabs : $fastKeyTabs");
      }
      // if(fastKeyTabs.length != response.fastkeys.length){
      ///if all the data mismatches then delete all db contents and replace with API response
      // Build #1.0.200: Clear existing data "await" added, everywhere we have added await while deleting data!
      // Code Updated : Empty fastkey folders show at first logon to multiple fastkeys loaded on created by the user
      await fastKeyDBHelper.deleteAllFastKeyTab(userId);
      /// TESTED : We have to delete all products of each exiting tab, otherwise creating duplicate items
      // Build #1.0.204: Fixed -> Getting Duplicate Items After Login selecting new fastKey tab
      for (var tab in fastKeyTabs) {
        final tabServerId = tab[AppDBConst.fastKeyServerId];
        if (tabServerId != null) {
          await fastKeyDBHelper.deleteAllFastKeyProductItems(tabServerId);
        }
      }
      for(var fastkey in response.fastkeys){ // Build #1.0.207: updated fastKey itemCount value from api response
        await fastKeyDBHelper.addFastKeyTab(userId, fastkey.fastkeyTitle, fastkey.fastkeyImage, fastkey.itemCount, int.parse(fastkey.fastkeyIndex), fastkey.fastkeyServerId );

        // Build #1.0.197: Fixed [SCRUM - 328] -> At first logon Empty items shows in fast keys for the selected folder
        /// Added FastKey items for this tab from API response
        if (kDebugMode) {
          print("#### Processing ${fastkey.products?.length} products for FastKey serverId: ${fastkey.fastkeyServerId}");
        }
        for (var product in fastkey.products ?? []) {
          var tagg = product.tags?.firstWhere((element) => element.name == TextConstants.age_restricted, orElse: () => Tags());
          var hasAgeRestriction = tagg?.name?.contains(TextConstants.age_restricted) ?? false;
          if (kDebugMode) {
            print("#### Adding FastKey item: ${product.name}, productId: ${product.productId}, hasAgeRestriction: $hasAgeRestriction");
          }
          await fastKeyDBHelper.addFastKeyItem(
            fastkey.fastkeyServerId,
            product.name,
            product.image,
            product.price,
            product.productId,
            // minAge: int.parse(tagg?.slug ?? "0"),
            minAge: int.tryParse(tagg?.slug ?? "") ?? 0,
            slNumber: product.slNumber,
            hasVariant: product.hasVariant ?? false,
          );
        }
      }
      // } else {
      //   ///else just update the data for each fast key
      // //  var i = 0; ///@Naveen please correct this logic use tabid instead of i
      //   for (var fastkey in response.fastkeys) {
      //     // Try to find the matching local tab by server ID
      //     final matchingTab = fastKeyTabs.firstWhere(
      //           (tab) => tab[AppDBConst.fastKeyServerId] == fastkey.fastkeyServerId,
      //           orElse: () => {},
      //     );
      //
      //     if (matchingTab.isNotEmpty) {
      //       final tabId = matchingTab[AppDBConst.fastKeyId];
      //       final updatedTab = {
      //         AppDBConst.fastKeyTabTitle: fastkey.fastkeyTitle.toString(),
      //         AppDBConst.fastKeyTabItemCount: fastkey.itemCount
      //       };
      //       await fastKeyDBHelper.updateFastKeyTab(tabId, updatedTab);
      //
      //       if (kDebugMode) {
      //         print("Updated tab $tabId with title ${fastkey.fastkeyTitle}");
      //       }
      //     } else {
      //       if (kDebugMode) {
      //         print("No matching tab found for fastKeyServerId: ${fastkey.fastkeyServerId}");
      //       }
      //     }
      //   }
      // }
      getFastKeysSink.add(APIResponse.completed(response));
    } catch (e, s) {
      if (e.toString().contains('Unauthorised')) {
        getFastKeysSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        getFastKeysSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        getFastKeysSink.add(APIResponse.error("Failed to fetch FastKeys: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in fetchFastKeysByUser: $e , Stack: $s");
    }
  }

  // Build #1.0.19: Add this method to your FastKeyBloc class
  Future<void> deleteFastKey(int fastkeyServerId, int userId) async {
    if (_deleteFastKeyController.isClosed) return;

    deleteFastKeySink.add(APIResponse.loading(TextConstants.loading));
    try {
      final response = await _fastKeyRepository.deleteFastKey(fastkeyServerId);
      // Build #1.0.87: Delete from DB after successful API response
      await FastKeyDBHelper().deleteFastKeyTab(fastkeyServerId);
      if (kDebugMode) {
        print("FastKeyBloc - Deleted FastKey from DB: $fastkeyServerId");
      }
      // Update active tab if the deleted tab was active
      final activeTabId = await FastKeyDBHelper().getActiveFastKeyTab();
      if (activeTabId == fastkeyServerId) {
        final tabs = await FastKeyDBHelper().getFastKeyTabsByUserId(userId);
        if (tabs.isNotEmpty) {
          await FastKeyDBHelper().saveActiveFastKeyTab(tabs.first[AppDBConst.fastKeyServerId]);
          if (kDebugMode) {
            print("FastKeyBloc - Updated active tab to: ${tabs.first[AppDBConst.fastKeyServerId]}");
          }
        } else {
          await FastKeyDBHelper().saveActiveFastKeyTab(null);
          if (kDebugMode) {
            print("FastKeyBloc - No tabs left, cleared active tab");
          }
        }
      }
      deleteFastKeySink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        deleteFastKeySink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        deleteFastKeySink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        deleteFastKeySink.add(APIResponse.error("Failed to delete FastKey: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in deleteFastKey: $e");
    }
  }

  // Build #1.0.89: Added updateFastKey API method
  Future<void> updateFastKey({
    required String title,
    required int index,
    required String imageUrl,
    required int fastKeyServerId,
    required int userId
  }) async {
    if (_updateFastKeyController.isClosed) return;

    updateFastKeySink.add(APIResponse.loading(TextConstants.loading));
    try {
      final request = FastKeyRequest(
        fastkeyTitle: title,
        fastkeyIndex: index,
        fastkeyImage: imageUrl,
        fastkeyServerId: fastKeyServerId,
      );

      final response = await _fastKeyRepository.updateFastKey(request);

      if (kDebugMode) {
        print("FastKeyBloc - Updated FastKey: ${response.fastkeyId}");
      }

      //Build #1.0.184: it will update all fastkey, including reorder indexes; so no need of below code for now
      // Build #1.0.89: Update DB after successful API response
      // final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
      // await fastKeyDBHelper.updateFastKeyTab(fastKeyServerId, {
      //   AppDBConst.fastKeyTabTitle: response.fastkeyTitle,
      //   AppDBConst.fastKeyTabImage: response.fastkeyImage,
      //   AppDBConst.fastKeyTabIndex: response.fastkeyIndex.toString(),
      // });
      if (kDebugMode) {
        print("### FastKeyBloc: Updated tab in DB with server ID: ${response.fastkeyId}");
      }

      await fetchFastKeysByUser(userId);
      updateFastKeySink.add(APIResponse.completed(response)); // Build #1.0.184
      //no need of user id to pass
    } catch (e, s) {
      if (e.toString().contains('Unauthorised')) {
        updateFastKeySink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else {
        updateFastKeySink.add(
            APIResponse.error(GlobalUtility.extractErrorMessage(e)));
      }//Build #1.0.189: Proper error not showing while getting error in update fast key
      if (kDebugMode) print("Exception in updateFastKey: $e, Stack: $s");
    }
  }

// Update the dispose method to include the new controller
  void dispose() {
    if (!_createFastKeyController.isClosed) {
      _createFastKeyController.close();
    }
    if (!_getFastKeysController.isClosed) {
      _getFastKeysController.close();
    }
    if (!_deleteFastKeyController.isClosed) { // Build #1.0.19
      _deleteFastKeyController.close();
    }
    if (!_updateFastKeyController.isClosed) { // Build #1.0.89
      _updateFastKeyController.close();
    }
    if (kDebugMode) print("FastKeyBloc disposed");
  }
}