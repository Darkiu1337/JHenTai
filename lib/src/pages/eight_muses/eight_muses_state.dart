import 'package:flutter/material.dart';
import 'package:jhentai/src/model/eight_muses_search.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/network/eight_muses_request.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class EightMusesState {
  final EightMusesSearchConfig config = EightMusesSearchConfig();

  final List<Gallery> galleries = <Gallery>[];

  EightMusesListing listing = EightMusesListing.popular;

  int nextPage = 1;

  LoadingState loadingState = LoadingState.idle;

  final ScrollController scrollController = ScrollController();

  final TextEditingController searchController = TextEditingController();

  final FocusNode searchFocusNode = FocusNode();

  bool showSuggestions = false;

  /// Pages/cards pulled from the site, before local filtering.
  int scannedPages = 0;
  int scannedCards = 0;
}
