import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../home/presentation/widgets/home_news_section.dart';
import '../../../home/presentation/widgets/home_surface.dart';
import '../../domain/pet_news_item.dart';

/// One story of the news page, drawn as on Home: up to three lines of title,
/// the source, and the sign that it opens outside the app.
class PetNewsCard extends StatelessWidget {
  const PetNewsCard({super.key, required this.item});

  final PetNewsItem item;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      child: HomeNewsRow(
        item: item,
        onTap: () => launchUrl(Uri.parse(item.sourceUrl), webOnlyWindowName: '_blank'),
      ),
    );
  }
}
