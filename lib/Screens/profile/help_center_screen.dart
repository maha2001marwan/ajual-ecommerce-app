import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/animations/motion.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/error_handler.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/ui.dart';

/// Help Center: searchable FAQ accordion.
/// Animations: staggered questions, accordion arrow rotates and the answer
/// expands, list filters with a cross-fade while typing.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  static const _faq = [
    ('How do I track my order?',
        'Open Account → My Orders, tap the order, then Track Order. You also get a notification at every step.'),
    ('Can I cancel an order?',
        'Yes, while it is "Ongoing" and not yet shipped. Open the order and tap Cancel Order.'),
    ('How do returns work?',
        'Completed orders show a Return / Refund button. Pick a reason and our team will contact you.'),
    ('Which payment methods are available?',
        'Cash on delivery is live. Card and PayPal payments are simulated in this version — no money is charged.'),
    ('When is shipping free?',
        'Standard shipping is free for orders of \$1,000 or more. Coupons such as FREESHIP also remove the fee.'),
    ('How do I use a promo code?',
        'Enter it in the cart or at checkout, or pick one from Account → My Coupons.'),
    ('Is my card information safe?',
        'We only keep the card brand, the last 4 digits, the holder name and expiry date. The full number and CVV are never stored.'),
  ];

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items = _faq
        .where((f) =>
            _query.isEmpty ||
            f.$1.toLowerCase().contains(_query.toLowerCase()) ||
            f.$2.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'Help Center'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              hintText: 'Search help articles',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey(_query),
              children: items.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No matching articles.', style: TextStyle(color: Appcolors.secondaryText)),
                      ),
                    ]
                  : staggered([for (final f in items) _FaqTile(question: f.$1, answer: f.$2)], stepMs: 45),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _open ? Appcolors.field : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Appcolors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.question, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 240),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          widget.answer,
                          style: const TextStyle(fontSize: 12.5, color: Appcolors.secondaryText, height: 1.5),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Customer Service: contact channels.
/// Animations: staggered channel cards, headset icon wobble, copy feedback.
class CustomerServiceScreen extends StatelessWidget {
  const CustomerServiceScreen({super.key});

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    AppFeedback.success('$label copied: $value');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'Customer Service'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: _WobbleHeadset()),
          const SizedBox(height: 16),
          const Text(
            'How can we help?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Our team replies within 24 hours, Saturday to Thursday.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Appcolors.secondaryText),
          ),
          const SizedBox(height: 24),
          ...staggered([
            _Channel(
              icon: Icons.mail_outline_rounded,
              title: 'Email us',
              subtitle: AppConfig.supportEmail,
              onTap: () => _copy('Email', AppConfig.supportEmail),
            ),
            _Channel(
              icon: Icons.phone_outlined,
              title: 'Call us',
              subtitle: AppConfig.supportPhone,
              onTap: () => _copy('Phone number', AppConfig.supportPhone),
            ),
            _Channel(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Live chat',
              subtitle: 'Needs a chat backend — demo',
              badge: const DemoBadge(),
              onTap: () => AppFeedback.demo('Live chat needs a paid chat service or Cloud Functions.'),
            ),
          ], stepMs: 80),
        ],
      ),
    );
  }
}

class _Channel extends StatelessWidget {
  const _Channel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Appcolors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Appcolors.primary, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (badge != null) ...[const SizedBox(width: 8), badge!],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Appcolors.secondaryText)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _WobbleHeadset extends StatefulWidget {
  const _WobbleHeadset();

  @override
  State<_WobbleHeadset> createState() => _WobbleHeadsetState();
}

class _WobbleHeadsetState extends State<_WobbleHeadset> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: Tween<double>(begin: -0.02, end: 0.02).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(color: Appcolors.field, shape: BoxShape.circle),
        child: const Icon(Icons.headset_mic_outlined, size: 44),
      ),
    );
  }
}
