import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A transient operational notice rendered by the root ToastHost. Durable
/// progress and reward outcomes are prohibited here and use receipts instead.
class ToastMessage {
  ToastMessage({
    required this.title,
    this.subtitle,
    this.icon = Icons.bolt_rounded,
    this.color,
  }) : id = DateTime.now().microsecondsSinceEpoch;
  final int id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? color;
}

class ToastController extends Notifier<List<ToastMessage>> {
  @override
  List<ToastMessage> build() => const [];

  void push(ToastMessage msg) {
    state = [...state, msg];
    Future.delayed(const Duration(milliseconds: 2600), () => dismiss(msg.id));
  }

  void dismiss(int id) {
    state = state.where((m) => m.id != id).toList();
  }
}

final toastProvider = NotifierProvider<ToastController, List<ToastMessage>>(
  ToastController.new,
);
