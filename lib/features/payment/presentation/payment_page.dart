import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:ecommerce_app/core/constants/app_colors.dart';
import 'package:ecommerce_app/core/constants/payment_constatns.dart';
import '../models/payment_result.dart';

class PaymentPage extends StatefulWidget {
  final String paymentUrl;
  final String transactionId;

  const PaymentPage({
    super.key,
    required this.paymentUrl,
    required this.transactionId,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _checkNavigation(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _checkNavigation(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            final handled = _checkNavigation(request.url);
            if (handled) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  bool _matchesCallback(String url, String configuredUrl, String pathSegment) {
    if (url.startsWith(configuredUrl) || url.contains(configuredUrl)) {
      return true;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    return path.endsWith('/$pathSegment') || path.contains('/payment/$pathSegment');
  }

  bool _checkNavigation(String url) {
    if (_handled || !mounted) return true;

    if (_matchesCallback(url, PaymentConstants.successUrl, 'success')) {
      _handled = true;
      context.pop(PaymentResult.success(transactionId: widget.transactionId));
      return true;
    }

    if (_matchesCallback(url, PaymentConstants.cancelUrl, 'cancel')) {
      _handled = true;
      context.pop(PaymentResult.cancelled());
      return true;
    }

    if (_matchesCallback(url, PaymentConstants.failUrl, 'fail')) {
      _handled = true;
      context.pop(
        PaymentResult.failed(message: 'Transaction failed at gateway'),
      );
      return true;
    }

    return false;
  }

  Future<void> _handleClose() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Payment?'),
        content: const Text(
          'Are you sure you want to exit? Your order will not be placed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continue Payment'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && !_handled && mounted) {
      _handled = true;
      context.pop(PaymentResult.cancelled());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleClose();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment Gateway'),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.xmark),
            onPressed: _handleClose,
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
