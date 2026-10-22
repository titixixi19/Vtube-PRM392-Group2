import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/config/api_config.dart';

/// Ảnh từ mạng có cache + ô xám khi đang tải / lỗi. Tự ghép URL tương đối với base URL.
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AppNetworkImage({super.key, required this.url, this.fit = BoxFit.cover, this.width, this.height, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final resolved = ApiConfig.resolveUrl(url);
    final placeholder = Container(width: width, height: height, color: AppColors.surfaceHigh);
    final Widget image = resolved == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: resolved,
            fit: fit,
            width: width,
            height: height,
            placeholder: (_, __) => placeholder,
            errorWidget: (_, __, ___) => placeholder,
          );
    return borderRadius == null ? image : ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
