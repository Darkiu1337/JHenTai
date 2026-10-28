import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/widget/eh_image.dart';

/// Grid card for an external (8muses) gallery.
///
/// Deliberately not [EHGalleryListCard]: that one expects E-H specific fields
/// (a parseable `publishTime`, E-H categories and tag namespaces) which the
/// external source does not provide.
class EightMusesCard extends StatelessWidget {
  final Gallery gallery;
  final VoidCallback onTap;

  const EightMusesCard({
    Key? key,
    required this.gallery,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: EHImage(
              galleryImage: gallery.cover,
              autoLayout: true,
              fit: BoxFit.cover,
              containerColor: UIConfig.galleryCardBackGroundColor(context),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            gallery.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.2),
          ),
          if (gallery.pageCount != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${gallery.pageCount} ${'pageCount'.tr}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: UIConfig.galleryCardTextColor(context)),
              ),
            ),
        ],
      ),
    );
  }
}
