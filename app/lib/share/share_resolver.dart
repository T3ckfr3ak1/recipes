import '../models/recipe.dart';
import 'description_recipe.dart';
import 'incoming_share.dart';
import 'page_description.dart';

final class ShareResolution {
  const ShareResolution({required this.detail, this.recipe});

  final Recipe? recipe;

  /// The description that was read, or why there was nothing to save.
  final String detail;
}

final class ShareResolver {
  ShareResolver({required this.pages, this.clock});

  final PageDescription pages;
  final DateTime Function()? clock;

  Future<ShareResolution> resolve(IncomingShare share) async {
    final now = clock?.call() ?? DateTime.now();
    final caption = share.caption.trim();
    final link = share.url;
    if (caption.isNotEmpty) {
      final recipe = recipeFromDescription(
        caption,
        now: now,
        subject: share.subject,
        pageUrl: link,
      );
      if (recipe != null) {
        return ShareResolution(recipe: recipe, detail: caption);
      }
    }
    if (link != null) {
      final uri = Uri.tryParse(link);
      final fetched = uri == null ? null : await pages.lookup(uri);
      final description = fetched?.trim() ?? '';
      if (description.isEmpty) {
        if (caption.isEmpty) {
          return const ShareResolution(
            detail:
                "That share didn't include a description, and the video page didn't either.",
          );
        }
        return ShareResolution(
          detail:
              "That video's description didn't include an ingredient list.\n\n$caption",
        );
      }
      final recipe = recipeFromDescription(
        description,
        now: now,
        subject: share.subject,
        pageUrl: link,
      );
      if (recipe != null && _sameDish(caption, recipe, description)) {
        return ShareResolution(recipe: recipe, detail: description);
      }
      if (caption.isNotEmpty && recipe != null) {
        return ShareResolution(
          detail:
              "The video page described a different recipe, so nothing was saved.\n\n$caption",
        );
      }
      final shown = caption.isNotEmpty ? caption : description;
      return ShareResolution(
        detail:
            "That video's description didn't include an ingredient list.\n\n$shown",
      );
    }
    if (caption.isEmpty) {
      return const ShareResolution(
        detail: "That share didn't include a description.",
      );
    }
    return ShareResolution(
      detail: "The description doesn't include a recipe.\n\n$caption",
    );
  }
}

const _captionSkip = {
  'this',
  'that',
  'with',
  'from',
  'your',
  'have',
  'just',
  'recipe',
  'video',
  'watch',
  'facebook',
  'reel',
  'https',
  'http',
  'check',
  'these',
  'those',
  'made',
};

/// A fetched page is only used when it is about the dish that was shared.
bool _sameDish(String caption, Recipe recipe, String description) {
  final words = caption
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.length >= 4 && !_captionSkip.contains(word))
      .toSet();
  if (words.isEmpty) return true;
  final haystack = '${recipe.title}\n$description'.toLowerCase();
  final hits = words.where(haystack.contains).length;
  return hits > 0 && hits * 2 >= words.length;
}
