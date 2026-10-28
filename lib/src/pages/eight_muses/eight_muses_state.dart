import 'package:flutter/material.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/network/eight_muses_request.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class EightMusesState {
  final List<Gallery> galleries = <Gallery>[];

  EightMusesListing listing = EightMusesListing.popular;

  /// Empty while browsing a listing, otherwise the active search keyword.
  String keyword = '';

  int nextPage = 1;

  LoadingState loadingState = LoadingState.idle;

  final ScrollController scrollController = ScrollController();
}
