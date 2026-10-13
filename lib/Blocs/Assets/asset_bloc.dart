import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Database/assets_db_helper.dart';
import '../../Database/db_helper.dart';
import '../../Helper/api_response.dart';
import '../../Models/Assets/asset_model.dart';
import '../../Repositories/Assets/asset_repository.dart';

class AssetBloc { //Build #1.0.40
  final AssetRepository _assetRepository;
  final StreamController<APIResponse<AssetResponse>> _assetController =
  StreamController<APIResponse<AssetResponse>>.broadcast();

  StreamSink<APIResponse<AssetResponse>> get assetSink => _assetController.sink;
  Stream<APIResponse<AssetResponse>> get assetStream => _assetController.stream;

  // Build #1.0.163: Added Image assets api
  final StreamController<APIResponse<ImageAssetsResponse>> _imageAssetController =
  StreamController<APIResponse<ImageAssetsResponse>>.broadcast();

  StreamSink<APIResponse<ImageAssetsResponse>> get imageAssetSink => _imageAssetController.sink;
  Stream<APIResponse<ImageAssetsResponse>> get imageAssetStream => _imageAssetController.stream;

  AssetBloc(this._assetRepository) {
    if (kDebugMode) {
      print("************** AssetBloc Initialized");
    }
  }

  Future<void> fetchImageAssets({bool forceRefresh = false}) async {
    if (_imageAssetController.isClosed) return;

    imageAssetSink.add(APIResponse.loading(TextConstants.loading));

    try {
      final db = await AssetDBHelper.instance.database;

      // Check if cached image assets exist
      final cachedMedia = await db.query(AppDBConst.mediaTable, limit: 1);
      if (cachedMedia.isNotEmpty && !forceRefresh) {
        if (kDebugMode) print("Loading image assets from cache");

        // Convert cached media to ImageAssetsResponse
        List<Media> mediaList = cachedMedia.map((e) => Media.fromMap(e)).toList();
        ImageAssetsResponse cachedResponse = ImageAssetsResponse(media: mediaList);

        imageAssetSink.add(APIResponse.completed(cachedResponse));
        return; // Exit since we already loaded from cache
      }

      // Fetch from API if cache is empty or forced refresh
      if (kDebugMode) print("Fetching image assets from API");

      ImageAssetsResponse response = await _assetRepository.getImageAssets();

      // Save to DB (delete old first)
      final existingAsset = await db.query(AppDBConst.assetTable, limit: 1);
      int assetId = existingAsset.isNotEmpty ? 1 : 1;

      await db.delete(AppDBConst.mediaTable, where: '${AppDBConst.assetId} = ?', whereArgs: [assetId]);
      for (var media in response.media) {
        await db.insert(AppDBConst.mediaTable, {
          ...media.toMap(),
          AppDBConst.assetId: assetId,
        });
      }

      if (kDebugMode) print("Saved ${response.media.length} image assets to DB");

      imageAssetSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        imageAssetSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        imageAssetSink.add(APIResponse.error("Failed to fetch image assets: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in fetchImageAssets: $e");
    }
  }

  Future<void> fetchAssets() async {
    if (_assetController.isClosed) return;

    assetSink.add(APIResponse.loading(TextConstants.loading));
    try {
      AssetResponse assetResponse = await _assetRepository.getAssets();
      await AssetDBHelper.instance.saveAssets(assetResponse); //Build #1.0.54: Save to Assets DB
      assetSink.add(APIResponse.completed(assetResponse));
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        assetSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        assetSink.add(APIResponse.error("Failed to fetch assets: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in fetchAssets: $e");
    }
  }

  // Build #1.0.163: Added Image assets api
  // Future<void> fetchImageAssets() async {
  //   if (_imageAssetController.isClosed) return;
  //
  //   imageAssetSink.add(APIResponse.loading(TextConstants.loading));
  //   try {
  //     if (kDebugMode) {
  //       print("************** Fetching image assets in background");
  //     }
  //     // Call the API without UI loading indicators
  //     ImageAssetsResponse response = await _assetRepository.getImageAssets();
  //
  //     // Get the current asset ID (usually 1)
  //     final db = await AssetDBHelper.instance.database;
  //     final existingAsset = await db.query(AppDBConst.assetTable, limit: 1);
  //     int assetId = existingAsset.isNotEmpty ? 1 : 1;
  //
  //     // Delete existing media and save new ones
  //     await db.delete(AppDBConst.mediaTable, where: '${AppDBConst.assetId} = ?', whereArgs: [assetId]);
  //
  //     for (var media in response.media) { // Build #1.0.163
  //       await db.insert(AppDBConst.mediaTable, {
  //         ...media.toMap(),
  //         AppDBConst.assetId: assetId,
  //       });
  //       if (kDebugMode) {
  //           print("#### fetchImageAssets: Inserted media with ID: ${media.id}");
  //        }
  //     }
  //
  //     if (kDebugMode) {
  //       print("************** Successfully saved ${response.media.length} image assets to DB");
  //     }
  //     imageAssetSink.add(APIResponse.completed(response));
  //   } catch (e) {
  //     if (e.toString().contains('SocketException')) {
  //       imageAssetSink.add(APIResponse.error("Network error. Please check your connection."));
  //     } else {
  //       imageAssetSink.add(APIResponse.error("Failed to fetch image assets: ${e.toString()}"));
  //     }
  //     if (kDebugMode) print("Exception in fetchImageAssets: $e");
  //   }
  // }

  void dispose() {
    if (!_assetController.isClosed) {
      _assetController.close();
      if (kDebugMode) print("AssetBloc disposed");
    }
    if (!_imageAssetController.isClosed) {_imageAssetController.close();}
  }
}