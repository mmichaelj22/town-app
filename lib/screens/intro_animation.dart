import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'dart:async';

class IntroAnimation extends StatefulWidget {
  final Widget nextScreen;

  const IntroAnimation({
    Key? key,
    required this.nextScreen,
  }) : super(key: key);

  @override
  _IntroAnimationState createState() => _IntroAnimationState();
}

class _IntroAnimationState extends State<IntroAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _backgroundFadeAnimation;
  late Animation<double> _taglineAnimation;

  @override
  void initState() {
    super.initState();

    // Set the status bar to be transparent during intro
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Initialize the animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Logo scale animation (bounce effect)
    _logoScaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticIn)),
        weight: 40,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6),
      ),
    );

    // Logo fade-in animation
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // Background animation (appears after logo)
    _backgroundFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );

    // Tagline animation (appears last)
    _taglineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.8, curve: Curves.easeIn),
      ),
    );

    // Start the animation
    _controller.forward();

    // Automatically navigate to the next screen after animation
    Timer(const Duration(milliseconds: 3000), () {
      // Mark intro as seen
      _markIntroAsSeen();

      // Navigate to next screen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              widget.nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.ease;

            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  Future<void> _markIntroAsSeen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_seen', true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Animated background
          FadeTransition(
            opacity: _backgroundFadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.blue.withOpacity(0.2),
                    AppTheme.yellow.withOpacity(0.2),
                  ],
                ),
              ),
            ),
          ),

          // Background decorative elements
          FadeTransition(
            opacity: _backgroundFadeAnimation,
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.coral.withOpacity(0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -150,
                  left: -100,
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.blue.withOpacity(0.1),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.3,
                  right: -60,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.yellow.withOpacity(0.1),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main content - Logo and tagline
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                FadeTransition(
                  opacity: _logoFadeAnimation,
                  child: ScaleTransition(
                    scale: _logoScaleAnimation,
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 160,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // App name
                // FadeTransition(
                //   opacity: _logoFadeAnimation,
                //   child: const Text(
                //     'Town',
                //     style: TextStyle(
                //       fontSize: 40,
                //       fontWeight: FontWeight.bold,
                //       letterSpacing: 1.2,
                //     ),
                //   ),
                // ),

                const SizedBox(height: 16),

                // Animated tagline
                FadeTransition(
                  opacity: _taglineAnimation,
                  child: Text(
                    'the square where neighbors meet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      letterSpacing: 0.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
