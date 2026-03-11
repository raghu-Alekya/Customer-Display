
import 'package:flutter/foundation.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Models/Search/product_search_model.dart';
import '../Blocs/Search/product_search_bloc.dart';
import '../Constants/text.dart';
import 'api_response.dart';


// Mock Test Item Class
class ProductItem {
  final String label;
  dynamic value;

  ProductItem({required this.label, this.value});

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(label: json['label'], value: json['value']);
  }
}

class SearchProduct {
  final _productBloc = ProductBloc(ProductRepository());
  List _productList = <dynamic>[];
  List get productList => _productList;
  bool isOnline = true;
  // Build #1.1.226: Fixed - updated xCountryCode to global string to fix the destinationController not getting auto search result because country code is empty
  // Cause: SearchAutoSuggest _autoSuggest; is initializing second time when AddDestination calls, that time xCountryCode is empty
  //String xCountryCode ="";

  set productList(List value) {
    _productList = value;

  }
  SearchProduct(){

  }

  Future<List> getProductResults() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (kDebugMode) {
      print("1 auto_search.getProductResults object######################### ${_productList.length} \n");
    }
    return _productList;
  }
  listentextchange(String text) async {
    // fetchSimpleData();
   // _autoSuggestExample(text , isChooseOnMapAvailable);
    _productList.clear();
    if (kDebugMode) {
      print("auto_search.listentextchange ######################### $text, $_productList \n");
      _productList.forEach((element) {
        print("auto_search.listentextchange product #########################${element.label} \n");
      });
    }
    if(text.isEmpty){
      return [];
    }
    await _productBloc.fetchProducts(searchQuery: text).whenComplete((){
      _loadProduct();
      if (kDebugMode) {
        print("2 auto_search.listentextchange object#########################${_productList.length} \n");
      }
    });
    if (kDebugMode) {
      print("3 auto_search.listentextchange object#########################${_productList.length} \n");
    }
  }

  Future<List> fetchSimpleData() async {
    // await Future.delayed(Duration(milliseconds: 2000));
    _productList.clear();
    _productList.add(ProductItem(label: "Milk",value: ""));
    _productList.add(ProductItem(label: "Milk1",value: ""));
    return _productList;
  }

  Future<List> _loadProduct() async{

    ///perform search and update the productList
    _productBloc.productStream.listen((event) async{
      if (kDebugMode) {
        print('status: ${event.status}');
      }
      if (event.status == Status.ERROR) {
        if (kDebugMode) {
          print('auto_search _fetchProductByText: fetch completed with ERROR');
        }
        _productBloc.productSink.add(APIResponse.error(TextConstants.retryText));
        _productBloc.productController.close();
      } else if (event.status == Status.COMPLETED) { // #Build 1.1.97: Fixed Issue -> subscription screen is coming every first time even user have byPassSubscription is true
        final products = event.data!;
        _productList.clear();
        if (kDebugMode) {
          print('auto_search _fetchProductByText fetch product completed with product count ${products.length}');
        }
        if (products == null || products.isEmpty || products.length == 0) {
          _productList.add(ProductItem(label: "No products found",value: ""));
        } else {
          for (ProductResponse product in products) {
            _productList.add(ProductItem(label: product.name ?? "Unknown", value: product));
          }
        }
        // if (!_productBloc.productController.isClosed) {
        //   _productBloc.productSink.add(APIResponse.completed([]));
        // }

      }
    },onDone: (){

    });

    return _productList;
  }

  Future<List> _autoSuggestExample(String text, bool isChooseOnMapAvailable) async {

    if (kDebugMode) {
      print("_autoSuggestExample ######################### $text, $_productList \n");
      _productList.forEach((element) {
        print("place#########################${element.label} \n");
      });
    }
    if(text.isEmpty){
      return [];
    }

    _productList.clear();

   ///perform search and update the productList

    return _productList;
  }

  // void searchResult(String text,  List<Suggestion>? list){
  //   if (searchError != null) {
  //     ///Add logs for the errors
  //     if (kDebugMode) {
  //       print("Auto suggest Error (Online): $text, $searchError");
  //     }
  //     return;
  //   }
  //   // If error is null, list is guaranteed to be not empty.
  //   int listLength = list!.length;
  //   if (kDebugMode) {
  //     print("Auto suggest results: $listLength.");
  //   }
  //   _productList.clear();
  //
  //  ///read the items from list and add to the product items before showing on UI
  //   // for (ProductItem autoSuggestResult in list) {
  //   //   String addressText = "Not a place.";
  //   //   Place? place = autoSuggestResult.place;
  //   //   // List _list = <dynamic>[];
  //   //   if (place != null) {
  //   //     var address = place.address.addressText.split(',');
  //   //     addressText = place.address.addressText;//.substring(0,55);
  //   //     if (kDebugMode) {
  //   //       print("place : ${place.address.addressText}.");
  //   //     }
  //   //     // addressText = place.address.street + place.address.state;
  //   //     _productList.add(ProductItem(label: addressText,value: place));
  //   //   }
  //   // }
  //   if (kDebugMode) {
  //     // _placelist.forEach((element) {
  //       // print("4 object#########################${element.label} \n");
  //     // });
  //
  //   }
  // }
}