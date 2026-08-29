import 'package:flutter/material.dart';

import 'package:evil_space/brand_logo.dart';
import 'package:evil_space/brand_surface.dart';

class AdminBuildConfig {
  AdminBuildConfig._();

  static const previewEnabled = bool.fromEnvironment(
    'EVIL_SPACE_ADMIN_PREVIEW',
    defaultValue: false,
  );
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  var _selectedSection = 0;

  static const _sections = <_AdminSection>[
    _AdminSection('TODAY', Icons.space_dashboard_outlined),
    _AdminSection('CUSTOMERS', Icons.people_outline),
    _AdminSection('PAYMENTS', Icons.receipt_long_outlined),
    _AdminSection('PURCHASES', Icons.shopping_bag_outlined),
    _AdminSection('NOTICES', Icons.notifications_none),
  ];

  @override
  Widget build(BuildContext context) {
    if (!AdminBuildConfig.previewEnabled) {
      return _AdminConnectionGate(onExit: widget.onExit);
    }

    return Scaffold(
      backgroundColor: BrandPalette.paper,
      body: BrandPaper(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 880;
              return Column(
                children: [
                  _AdminHeader(onExit: widget.onExit),
                  const _PreviewBanner(),
                  Expanded(
                    child: desktop
                        ? Row(
                            children: [
                              _NavigationRail(
                                sections: _sections,
                                selectedIndex: _selectedSection,
                                onSelected: _selectSection,
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(child: _sectionBody()),
                            ],
                          )
                        : Column(
                            children: [
                              _NavigationStrip(
                                sections: _sections,
                                selectedIndex: _selectedSection,
                                onSelected: _selectSection,
                              ),
                              const Divider(height: 1),
                              Expanded(child: _sectionBody()),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _selectSection(int index) => setState(() => _selectedSection = index);

  Widget _sectionBody() {
    return switch (_selectedSection) {
      0 => const _TodayPanel(),
      1 => const _CustomersPanel(),
      2 => const _PaymentsPanel(),
      3 => const _PurchasesPanel(),
      _ => const _NotificationsPanel(),
    };
  }
}

class _AdminConnectionGate extends StatelessWidget {
  const _AdminConnectionGate({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandPalette.paper,
      body: BrandPaper(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const EvilCoworkingLogo(width: 220),
                    const SizedBox(height: 32),
                    const Divider(color: BrandPalette.ink),
                    const SizedBox(height: 18),
                    Text('STAFF ACCESS', style: _adminMono(11, spacing: 1.1)),
                    const SizedBox(height: 22),
                    Text(
                      'Secure admin connection required.',
                      style: _adminSerif(36, height: 1.02),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'This route deliberately has no local password fallback. Connect Supabase Auth and apply the included row-level security migration before staff sign-in is enabled.',
                      style: _adminSerif(
                        18,
                        color: BrandPalette.inkMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _SecurityLine(
                      label: 'IDENTITY',
                      value: 'EMAIL MAGIC LINK / APPROVED STAFF ONLY',
                    ),
                    const _SecurityLine(
                      label: 'DATA',
                      value: 'POSTGRES + ROW-LEVEL SECURITY',
                    ),
                    const _SecurityLine(
                      label: 'BROWSER',
                      value: 'NO PASSWORDS OR ROLES IN LOCAL STORAGE',
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      onPressed: onExit,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: Text(
                        'BACK TO PUBLIC PAGE',
                        style: _adminMono(10.5),
                      ),
                      style: _adminButtonStyle(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.ink)),
      ),
      child: Row(
        children: [
          const EvilCoworkingLogo(width: 112),
          const SizedBox(width: 16),
          Text('OPERATIONS', style: _adminMono(10.5, spacing: 0.8)),
          const Spacer(),
          TextButton.icon(
            onPressed: onExit,
            icon: const Icon(Icons.logout, size: 17),
            label: Text('EXIT', style: _adminMono(10)),
            style: TextButton.styleFrom(
              foregroundColor: BrandPalette.ink,
              minimumSize: const Size(48, 48),
              shape: const RoundedRectangleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: BrandPalette.ink,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        'DESIGN PREVIEW  /  SAMPLE DATA  /  NO WRITES',
        textAlign: TextAlign.center,
        style: _adminMono(9.5, color: BrandPalette.paperLift, spacing: 0.75),
      ),
    );
  }
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_AdminSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return _NavigationItem(
            section: section,
            selected: index == selectedIndex,
            onPressed: () => onSelected(index),
          );
        },
      ),
    );
  }
}

class _NavigationStrip extends StatelessWidget {
  const _NavigationStrip({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_AdminSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: sections.length,
        separatorBuilder: (context, index) => const SizedBox(width: 4),
        itemBuilder: (context, index) => _NavigationItem(
          section: sections[index],
          selected: index == selectedIndex,
          onPressed: () => onSelected(index),
          compact: true,
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.section,
    required this.selected,
    required this.onPressed,
    this.compact = false,
  });

  final _AdminSection section;
  final bool selected;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(section.icon, size: 18),
      label: Text(section.label, style: _adminMono(9.5, spacing: 0.35)),
      style: TextButton.styleFrom(
        foregroundColor: selected ? BrandPalette.paperLift : BrandPalette.ink,
        backgroundColor: selected ? BrandPalette.ink : Colors.transparent,
        minimumSize: Size(compact ? 0 : 174, 46),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        shape: const RoundedRectangleBorder(),
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel();

  @override
  Widget build(BuildContext context) {
    return _PanelFrame(
      eyebrow: 'SATURDAY / 29 AUGUST',
      title: 'Today at Evil Space',
      action: const _PanelAction(label: 'UPDATE PUBLIC STATUS'),
      child: Column(
        children: [
          const _MetricGrid(
            metrics: [
              _Metric('FREE DESKS', '7'),
              _Metric('CHECK-INS', '3'),
              _Metric('PAYMENT DUE', '4'),
              _Metric('TO BUY', '2'),
            ],
          ),
          const SizedBox(height: 28),
          const _Subheading('NEEDS ATTENTION'),
          const _LedgerRow(
            title: '4 customer payments need review',
            meta: 'PAYMENTS  /  TODAY',
            status: 'REVIEW',
          ),
          const _LedgerRow(
            title: 'HDMI adapter for lecture room',
            meta: 'PURCHASE  /  HIGH PRIORITY',
            status: 'NEEDED',
          ),
          const _LedgerRow(
            title: '20 October opening checklist',
            meta: 'STUDIO + LECTURE ROOM',
            status: '12 TASKS',
          ),
        ],
      ),
    );
  }
}

class _CustomersPanel extends StatelessWidget {
  const _CustomersPanel();

  @override
  Widget build(BuildContext context) {
    return const _PanelFrame(
      eyebrow: 'CUSTOMER REGISTER',
      title: 'People using the space',
      action: _PanelAction(label: 'ADD CUSTOMER'),
      child: Column(
        children: [
          _LedgerRow(
            title: 'CUSTOMER #104',
            meta: 'MONTH PASS  /  DESK 04',
            status: 'ACTIVE',
          ),
          _LedgerRow(
            title: 'CUSTOMER #105',
            meta: 'DAY PASS  /  WALK-IN',
            status: 'TODAY',
          ),
          _LedgerRow(
            title: 'CUSTOMER #106',
            meta: 'MONTH PASS  /  PAYMENT DUE',
            status: 'CHECK',
          ),
        ],
      ),
    );
  }
}

class _PaymentsPanel extends StatelessWidget {
  const _PaymentsPanel();

  @override
  Widget build(BuildContext context) {
    return const _PanelFrame(
      eyebrow: 'PAYMENT LEDGER',
      title: 'Paid, due, and verified',
      action: _PanelAction(label: 'RECORD PAYMENT'),
      child: Column(
        children: [
          _LedgerRow(
            title: 'CUSTOMER #104  ·  2.5 MLN VND',
            meta: 'BANK TRANSFER  /  VERIFIED BY MANAGER',
            status: 'PAID',
          ),
          _LedgerRow(
            title: 'CUSTOMER #105  ·  250K VND',
            meta: 'CASH  /  RECEIPT #0182',
            status: 'PAID',
          ),
          _LedgerRow(
            title: 'CUSTOMER #106  ·  2.5 MLN VND',
            meta: 'DUE 01 SEPTEMBER',
            status: 'DUE',
          ),
        ],
      ),
    );
  }
}

class _PurchasesPanel extends StatelessWidget {
  const _PurchasesPanel();

  @override
  Widget build(BuildContext context) {
    return const _PanelFrame(
      eyebrow: 'SPACE PURCHASES',
      title: 'What we need and what was bought',
      action: _PanelAction(label: 'NEW REQUEST'),
      child: Column(
        children: [
          _LedgerRow(
            title: 'HDMI ADAPTER',
            meta: 'LECTURE ROOM  /  REQUESTED TODAY',
            status: 'NEEDED',
          ),
          _LedgerRow(
            title: '2 MICROPHONE CABLES',
            meta: 'STUDIO  /  APPROVED',
            status: 'BUY',
          ),
          _LedgerRow(
            title: 'COFFEE FILTERS',
            meta: 'KITCHEN  /  180K VND',
            status: 'BOUGHT',
          ),
        ],
      ),
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel();

  @override
  Widget build(BuildContext context) {
    return const _PanelFrame(
      eyebrow: 'STAFF NOTIFICATIONS',
      title: 'One event, every approved device',
      action: _PanelAction(label: 'SEND NOTICE'),
      child: Column(
        children: [
          _MetricGrid(
            metrics: [
              _Metric('DEVICES', '5'),
              _Metric('UNREAD', '2'),
              _Metric('DELIVERED', '98%'),
              _Metric('FAILED', '0'),
            ],
          ),
          SizedBox(height: 28),
          _Subheading('RECENT EVENTS'),
          _LedgerRow(
            title: 'Purchase marked bought: coffee filters',
            meta: 'ALL STAFF  /  14:22',
            status: 'SENT',
          ),
          _LedgerRow(
            title: 'Payment verified: customer #105',
            meta: 'OWNER + MANAGERS  /  11:04',
            status: 'SENT',
          ),
        ],
      ),
    );
  }
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({
    required this.eyebrow,
    required this.title,
    required this.child,
    this.action,
  });

  final String eyebrow;
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                eyebrow,
                style: _adminMono(10, color: BrandPalette.inkMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 14,
                children: [
                  Text(title, style: _adminSerif(34)),
                  ?action,
                ],
              ),
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 680 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics
              .map(
                (metric) => Container(
                  width: width,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: BrandPalette.ink),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metric.label, style: _adminMono(9.5)),
                      const SizedBox(height: 18),
                      Text(metric.value, style: _adminSerif(32)),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _Subheading extends StatelessWidget {
  const _Subheading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.ink)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(label, style: _adminMono(10.5, spacing: 0.7)),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.title,
    required this.meta,
    required this.status,
  });

  final String title;
  final String meta;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.rule)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: _adminSerif(18)),
                const SizedBox(height: 7),
                Text(
                  meta,
                  style: _adminMono(9.5, color: BrandPalette.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: BrandPalette.ink),
            ),
            child: Text(status, style: _adminMono(9)),
          ),
        ],
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  const _PanelAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: null,
      style: _adminButtonStyle(),
      child: Text(label, style: _adminMono(9.5)),
    );
  }
}

class _SecurityLine extends StatelessWidget {
  const _SecurityLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.rule)),
      ),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(label, style: _adminMono(9.5))),
          Expanded(
            child: Text(
              value,
              style: _adminMono(
                9.5,
                color: BrandPalette.inkMuted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSection {
  const _AdminSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}

ButtonStyle _adminButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: BrandPalette.ink,
    disabledForegroundColor: BrandPalette.ink,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    side: const BorderSide(color: BrandPalette.ink),
    shape: const RoundedRectangleBorder(),
  );
}

TextStyle _adminSerif(
  double size, {
  Color color = BrandPalette.ink,
  double height = 1.08,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['Times New Roman', 'serif'],
    fontSize: size,
    height: height,
  );
}

TextStyle _adminMono(
  double size, {
  Color color = BrandPalette.ink,
  double spacing = 0.4,
  double height = 1.2,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'Courier New',
    fontFamilyFallback: const ['monospace'],
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: spacing,
    height: height,
  );
}
