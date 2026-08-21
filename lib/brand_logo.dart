import 'package:flutter/material.dart';

import 'package:evil_space/brand_surface.dart';

class EvilCoworkingLogo extends StatelessWidget {
  const EvilCoworkingLogo({
    super.key,
    this.width,
  });

  static const double aspectRatio = 2.262548262548;

  final double? width;

  @override
  Widget build(BuildContext context) {
    final logo = AspectRatio(
      aspectRatio: aspectRatio,
      child: const RepaintBoundary(
        child: CustomPaint(
          painter: _EvilCoworkingLogoPainter(),
        ),
      ),
    );

    if (width == null) {
      return logo;
    }

    return SizedBox(
      width: width,
      child: logo,
    );
  }
}

class _EvilCoworkingLogoPainter extends CustomPainter {
  const _EvilCoworkingLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final scaleX = size.width / 586.0;
    final scaleY = size.height / 259.0;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    final path = Path()..fillType = PathFillType.evenOdd;
    path.moveTo(170.0, 187.0);
    path.lineTo(188.0, 187.0);
    path.lineTo(197.0, 166.0);
    path.lineTo(199.0, 167.0);
    path.lineTo(206.0, 187.0);
    path.lineTo(225.0, 187.0);
    path.lineTo(244.0, 136.0);
    path.lineTo(223.0, 136.0);
    path.lineTo(214.0, 160.0);
    path.lineTo(205.0, 136.0);
    path.lineTo(191.0, 136.0);
    path.lineTo(182.0, 159.0);
    path.lineTo(180.0, 158.0);
    path.lineTo(174.0, 136.0);
    path.lineTo(153.0, 136.0);
    path.close();
    path.moveTo(416.0, 135.0);
    path.lineTo(415.0, 187.0);
    path.lineTo(437.0, 187.0);
    path.lineTo(437.0, 136.0);
    path.close();
    path.moveTo(346.0, 135.0);
    path.lineTo(336.0, 136.0);
    path.lineTo(332.0, 138.0);
    path.lineTo(326.0, 145.0);
    path.lineTo(325.0, 136.0);
    path.lineTo(305.0, 136.0);
    path.lineTo(305.0, 187.0);
    path.lineTo(325.0, 187.0);
    path.lineTo(326.0, 162.0);
    path.lineTo(334.0, 154.0);
    path.lineTo(345.0, 153.0);
    path.close();
    path.moveTo(250.0, 140.0);
    path.lineTo(241.0, 150.0);
    path.lineTo(238.0, 160.0);
    path.lineTo(240.0, 173.0);
    path.lineTo(246.0, 181.0);
    path.lineTo(260.0, 188.0);
    path.lineTo(272.0, 189.0);
    path.lineTo(285.0, 186.0);
    path.lineTo(292.0, 182.0);
    path.lineTo(298.0, 176.0);
    path.lineTo(301.0, 170.0);
    path.lineTo(302.0, 158.0);
    path.lineTo(299.0, 149.0);
    path.lineTo(292.0, 141.0);
    path.lineTo(278.0, 135.0);
    path.lineTo(263.0, 135.0);
    path.close();
    path.moveTo(266.0, 151.0);
    path.lineTo(274.0, 151.0);
    path.lineTo(281.0, 158.0);
    path.lineTo(281.0, 166.0);
    path.lineTo(275.0, 173.0);
    path.lineTo(265.0, 173.0);
    path.lineTo(259.0, 166.0);
    path.lineTo(259.0, 159.0);
    path.lineTo(261.0, 155.0);
    path.close();
    path.moveTo(517.0, 136.0);
    path.lineTo(506.0, 145.0);
    path.lineTo(502.0, 155.0);
    path.lineTo(502.0, 166.0);
    path.lineTo(506.0, 176.0);
    path.lineTo(512.0, 182.0);
    path.lineTo(521.0, 186.0);
    path.lineTo(535.0, 186.0);
    path.lineTo(543.0, 182.0);
    path.lineTo(545.0, 184.0);
    path.lineTo(539.0, 192.0);
    path.lineTo(534.0, 194.0);
    path.lineTo(528.0, 193.0);
    path.lineTo(523.0, 189.0);
    path.lineTo(503.0, 189.0);
    path.lineTo(505.0, 197.0);
    path.lineTo(513.0, 205.0);
    path.lineTo(526.0, 209.0);
    path.lineTo(542.0, 208.0);
    path.lineTo(555.0, 203.0);
    path.lineTo(563.0, 195.0);
    path.lineTo(566.0, 187.0);
    path.lineTo(566.0, 135.0);
    path.lineTo(545.0, 135.0);
    path.lineTo(544.0, 139.0);
    path.lineTo(532.0, 134.0);
    path.lineTo(524.0, 134.0);
    path.close();
    path.moveTo(530.0, 150.0);
    path.lineTo(537.0, 150.0);
    path.lineTo(541.0, 152.0);
    path.lineTo(545.0, 159.0);
    path.lineTo(543.0, 166.0);
    path.lineTo(536.0, 171.0);
    path.lineTo(531.0, 171.0);
    path.lineTo(527.0, 169.0);
    path.lineTo(522.0, 161.0);
    path.lineTo(523.0, 156.0);
    path.close();
    path.moveTo(496.0, 142.0);
    path.lineTo(491.0, 137.0);
    path.lineTo(482.0, 134.0);
    path.lineTo(469.0, 136.0);
    path.lineTo(462.0, 141.0);
    path.lineTo(461.0, 135.0);
    path.lineTo(441.0, 135.0);
    path.lineTo(440.0, 187.0);
    path.lineTo(461.0, 187.0);
    path.lineTo(461.0, 161.0);
    path.lineTo(462.0, 157.0);
    path.lineTo(467.0, 152.0);
    path.lineTo(475.0, 153.0);
    path.lineTo(478.0, 158.0);
    path.lineTo(478.0, 187.0);
    path.lineTo(499.0, 187.0);
    path.lineTo(499.0, 150.0);
    path.close();
    path.moveTo(25.0, 137.0);
    path.lineTo(20.0, 150.0);
    path.lineTo(20.0, 164.0);
    path.lineTo(22.0, 171.0);
    path.lineTo(28.0, 180.0);
    path.lineTo(36.0, 186.0);
    path.lineTo(42.0, 194.0);
    path.lineTo(54.0, 205.0);
    path.lineTo(62.0, 209.0);
    path.lineTo(81.0, 212.0);
    path.lineTo(100.0, 209.0);
    path.lineTo(128.0, 199.0);
    path.lineTo(144.0, 198.0);
    path.lineTo(152.0, 201.0);
    path.lineTo(158.0, 206.0);
    path.lineTo(154.0, 209.0);
    path.lineTo(147.0, 211.0);
    path.lineTo(162.0, 219.0);
    path.lineTo(170.0, 227.0);
    path.lineTo(173.0, 233.0);
    path.lineTo(175.0, 227.0);
    path.lineTo(175.0, 209.0);
    path.lineTo(172.0, 199.0);
    path.lineTo(165.0, 204.0);
    path.lineTo(154.0, 194.0);
    path.lineTo(142.0, 190.0);
    path.lineTo(125.0, 191.0);
    path.lineTo(93.0, 201.0);
    path.lineTo(75.0, 201.0);
    path.lineTo(64.0, 196.0);
    path.lineTo(61.0, 193.0);
    path.lineTo(62.0, 191.0);
    path.lineTo(74.0, 188.0);
    path.lineTo(81.0, 184.0);
    path.lineTo(89.0, 177.0);
    path.lineTo(94.0, 170.0);
    path.lineTo(98.0, 177.0);
    path.lineTo(110.0, 186.0);
    path.lineTo(127.0, 188.0);
    path.lineTo(144.0, 183.0);
    path.lineTo(154.0, 174.0);
    path.lineTo(157.0, 166.0);
    path.lineTo(156.0, 153.0);
    path.lineTo(153.0, 147.0);
    path.lineTo(146.0, 140.0);
    path.lineTo(134.0, 135.0);
    path.lineTo(114.0, 136.0);
    path.lineTo(104.0, 141.0);
    path.lineTo(99.0, 146.0);
    path.lineTo(96.0, 151.0);
    path.lineTo(93.0, 164.0);
    path.lineTo(76.0, 166.0);
    path.lineTo(70.0, 172.0);
    path.lineTo(64.0, 175.0);
    path.lineTo(55.0, 175.0);
    path.lineTo(47.0, 171.0);
    path.lineTo(43.0, 167.0);
    path.lineTo(40.0, 160.0);
    path.lineTo(40.0, 153.0);
    path.lineTo(45.0, 143.0);
    path.lineTo(54.0, 137.0);
    path.lineTo(63.0, 136.0);
    path.lineTo(70.0, 139.0);
    path.lineTo(78.0, 148.0);
    path.lineTo(96.0, 141.0);
    path.lineTo(97.0, 139.0);
    path.lineTo(94.0, 133.0);
    path.lineTo(85.0, 124.0);
    path.lineTo(76.0, 119.0);
    path.lineTo(68.0, 117.0);
    path.lineTo(55.0, 117.0);
    path.lineTo(39.0, 123.0);
    path.close();
    path.moveTo(122.0, 151.0);
    path.lineTo(130.0, 151.0);
    path.lineTo(135.0, 155.0);
    path.lineTo(137.0, 159.0);
    path.lineTo(137.0, 165.0);
    path.lineTo(134.0, 170.0);
    path.lineTo(130.0, 173.0);
    path.lineTo(121.0, 173.0);
    path.lineTo(115.0, 167.0);
    path.lineTo(115.0, 157.0);
    path.close();
    path.moveTo(349.0, 113.0);
    path.lineTo(349.0, 187.0);
    path.lineTo(370.0, 187.0);
    path.lineTo(370.0, 174.0);
    path.lineTo(373.0, 171.0);
    path.lineTo(387.0, 187.0);
    path.lineTo(413.0, 187.0);
    path.lineTo(390.0, 159.0);
    path.lineTo(411.0, 136.0);
    path.lineTo(386.0, 136.0);
    path.lineTo(371.0, 152.0);
    path.lineTo(370.0, 113.0);
    path.close();
    path.moveTo(424.0, 108.0);
    path.lineTo(418.0, 111.0);
    path.lineTo(415.0, 115.0);
    path.lineTo(415.0, 124.0);
    path.lineTo(420.0, 130.0);
    path.lineTo(430.0, 131.0);
    path.lineTo(434.0, 129.0);
    path.lineTo(437.0, 125.0);
    path.lineTo(438.0, 116.0);
    path.lineTo(432.0, 109.0);
    path.close();
    path.moveTo(206.0, 75.0);
    path.lineTo(206.0, 119.0);
    path.lineTo(230.0, 118.0);
    path.lineTo(230.0, 75.0);
    path.close();
    path.moveTo(70.0, 75.0);
    path.lineTo(64.0, 83.0);
    path.lineTo(62.0, 90.0);
    path.lineTo(62.0, 99.0);
    path.lineTo(68.0, 111.0);
    path.lineTo(81.0, 119.0);
    path.lineTo(90.0, 121.0);
    path.lineTo(110.0, 120.0);
    path.lineTo(123.0, 114.0);
    path.lineTo(131.0, 105.0);
    path.lineTo(132.0, 101.0);
    path.lineTo(111.0, 101.0);
    path.lineTo(104.0, 106.0);
    path.lineTo(98.0, 107.0);
    path.lineTo(91.0, 105.0);
    path.lineTo(86.0, 100.0);
    path.lineTo(87.0, 97.0);
    path.lineTo(133.0, 97.0);
    path.lineTo(131.0, 82.0);
    path.lineTo(124.0, 73.0);
    path.lineTo(113.0, 67.0);
    path.lineTo(102.0, 65.0);
    path.lineTo(88.0, 66.0);
    path.lineTo(79.0, 69.0);
    path.close();
    path.moveTo(86.0, 86.0);
    path.lineTo(90.0, 81.0);
    path.lineTo(94.0, 79.0);
    path.lineTo(102.0, 79.0);
    path.lineTo(106.0, 81.0);
    path.lineTo(110.0, 87.0);
    path.lineTo(87.0, 88.0);
    path.close();
    path.moveTo(221.0, 50.0);
    path.lineTo(214.0, 56.0);
    path.lineTo(214.0, 65.0);
    path.lineTo(220.0, 71.0);
    path.lineTo(229.0, 71.0);
    path.lineTo(235.0, 65.0);
    path.lineTo(235.0, 56.0);
    path.lineTo(232.0, 52.0);
    path.lineTo(228.0, 50.0);
    path.close();
    path.moveTo(239.0, 49.0);
    path.lineTo(239.0, 118.0);
    path.lineTo(263.0, 118.0);
    path.lineTo(263.0, 49.0);
    path.close();
    path.moveTo(129.0, 26.0);
    path.lineTo(120.0, 32.0);
    path.lineTo(115.0, 39.0);
    path.lineTo(115.0, 54.0);
    path.lineTo(123.0, 63.0);
    path.lineTo(131.0, 68.0);
    path.lineTo(128.0, 68.0);
    path.lineTo(128.0, 70.0);
    path.lineTo(150.0, 118.0);
    path.lineTo(173.0, 118.0);
    path.lineTo(200.0, 68.0);
    path.lineTo(198.0, 67.0);
    path.lineTo(206.0, 62.0);
    path.lineTo(212.0, 55.0);
    path.lineTo(214.0, 50.0);
    path.lineTo(213.0, 39.0);
    path.lineTo(206.0, 30.0);
    path.lineTo(191.0, 23.0);
    path.lineTo(200.0, 32.0);
    path.lineTo(201.0, 40.0);
    path.lineTo(192.0, 51.0);
    path.lineTo(185.0, 54.0);
    path.lineTo(179.0, 60.0);
    path.lineTo(162.0, 94.0);
    path.lineTo(149.0, 60.0);
    path.lineTo(143.0, 54.0);
    path.lineTo(133.0, 49.0);
    path.lineTo(128.0, 42.0);
    path.lineTo(128.0, 33.0);
    path.lineTo(137.0, 23.0);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..color = BrandPalette.cream,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EvilCoworkingLogoPainter oldDelegate) => false;
}
