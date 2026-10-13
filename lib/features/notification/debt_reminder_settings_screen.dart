import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/controls/debt_reminder_service.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'utils/reminder_helpers.dart';
import 'widget/debt_reminder_card.dart';

class DebtReminderSettingsScreen extends StatefulWidget {
  const DebtReminderSettingsScreen({super.key});

  @override
  State<DebtReminderSettingsScreen> createState() =>
      _DebtReminderSettingsScreenState();
}

class _DebtReminderSettingsScreenState
    extends State<DebtReminderSettingsScreen> {
  late final DebtFirebase service;
  late final Stream<List<Debt>> stream;
  final busy = <String>{};

  @override
  void initState() {
    super.initState();
    service = DebtFirebase();
    stream = service.watchDebts();
  }

  Future<void> toggle(Debt d, bool enabled) async {
    if (busy.contains(d.id) ||
        FirebaseAuth.instance.currentUser?.uid != service.uid) {
      return;
    }
    setState(() => busy.add(d.id));
    try {
      if (enabled) {
        final allowed = await DebtReminderService.instance.requestPermission();
        if (!allowed) {
          throw StateError(
            reminderText(context, 'permission_enable_in_settings'),
          );
        }
      }
      await service.setReminderEnabled(d.id, enabled);
      await DebtReminderService.instance.refreshSafely(service.uid);
      final error = DebtReminderService.instance.lastError;
      if (error != null) {
        throw StateError(
          reminderText(
            context,
            'saved_but_sync_failed',
          ).replaceAll('{error}', error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reminderErrorText(context, e))));
      }
    } finally {
      if (mounted) setState(() => busy.remove(d.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SpendingStyle.background(context),
    appBar: AppBar(
      backgroundColor: SpendingStyle.background(context),
      title: Text(reminderText(context, 'debt_settings_title')),
    ),
    body: StreamBuilder<List<Debt>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) {
          return Center(child: Text(reminderText(context, 'debt_load_error')));
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final active = s.data!.where((d) => d.remaining > 0).toList();
        if (active.isEmpty) {
          return Center(
            child: Text(reminderText(context, 'no_debts_to_remind')),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: SpendingStyle.decoration(context, hero: true),
              child: Text(reminderText(context, 'debt_settings_note')),
            ),
            for (final d in active)
              DebtReminderCard(
                debt: d,
                busy: busy.contains(d.id),
                onChanged: (value) => toggle(d, value),
              ),
          ],
        );
      },
    ),
  );
}
