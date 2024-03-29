import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

/// Controls play and pause of [controller].
///
/// Toggles play/pause on tap (accompanied by a fading status icon).
///
/// Plays (looping) on initialization, and mutes on deactivation.
class VideoPlayPause extends StatefulWidget {
  final VideoPlayerController controller;

  VideoPlayPause(this.controller);

  @override
  State createState() {
    return _VideoPlayPauseState();
  }
}

class _VideoPlayPauseState extends State<VideoPlayPause> {
  FadeAnimation imageFadeAnim =
  FadeAnimation(child: const Icon(Icons.play_arrow, size: 40.0));
  VoidCallback listener;

  _VideoPlayPauseState() {
    listener = () {
//      setState(() {});
    };
  }

  VideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    print("video init");
    controller.addListener(listener);
    controller.setVolume(1.0);
    controller.play();
  }

  @override
  void deactivate() {
    if (controller != null) {
//      controller.setVolume(0.0);
      controller.removeListener(listener);
    }

    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      GestureDetector(
        child: VideoPlayer(controller),
        onTap: () {
          if (!controller.value.initialized) {
            return;
          }
          if (controller.value.isPlaying) {
            imageFadeAnim =
                FadeAnimation(child: const Icon(Icons.pause, size: 40.0));
            controller.pause();
          } else {
            imageFadeAnim =
                FadeAnimation(child: const Icon(Icons.play_arrow, size: 40.0));
            controller.play();
          }
        },
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: VideoProgressIndicator(
          controller,
          allowScrubbing: true,
        ),
      ),
      Center(child: imageFadeAnim),
      Center(
          child: controller.value.isBuffering
              ? const CircularProgressIndicator()
              : null),
    ];

    return Stack(
      fit: StackFit.passthrough,
      children: children,
    );
  }
}

class FadeAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;

  FadeAnimation(
      {this.child, this.duration = const Duration(milliseconds: 500)});

  @override
  _FadeAnimationState createState() => _FadeAnimationState();
}

class _FadeAnimationState extends State<FadeAnimation>
    with SingleTickerProviderStateMixin {
  AnimationController animationController;

  @override
  void initState() {
    super.initState();
    animationController =
        AnimationController(duration: widget.duration, vsync: this);
    animationController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    animationController.forward(from: 0.0);
  }

  @override
  void deactivate() {
    animationController.stop();
    super.deactivate();
  }

  @override
  void didUpdateWidget(FadeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return animationController.isAnimating
        ? Opacity(
      opacity: 1.0 - animationController.value,
      child: widget.child,
    )
        : Container();
  }
}

typedef Widget VideoWidgetBuilder(BuildContext context,
    VideoPlayerController controller);

abstract class PlayerLifeCycle extends StatefulWidget {
  VideoWidgetBuilder childBuilder;
  String dataSource;
  String preImageSource;
  File file;

  PlayerLifeCycle(this.childBuilder, this.dataSource, this.preImageSource,
      this.file);


}

/// A widget connecting its life cycle to a [VideoPlayerController] using
/// a data source from the network.
class NetworkPlayerLifeCycle extends PlayerLifeCycle {
  NetworkPlayerLifeCycle(String dataSource, String preImageSource,
      VideoWidgetBuilder childBuilder, File file)
      : super(childBuilder, dataSource, preImageSource, file);

  @override
  _NetworkPlayerLifeCycleState createState() => _NetworkPlayerLifeCycleState();
}

/// A widget connecting its life cycle to a [VideoPlayerController] using
/// an asset as data source
class AssetPlayerLifeCycle extends PlayerLifeCycle {
  AssetPlayerLifeCycle(String dataSource, String preImageSource,
      VideoWidgetBuilder childBuilder, File file)
      : super(childBuilder, dataSource, preImageSource, file);

  @override
  _AssetPlayerLifeCycleState createState() => _AssetPlayerLifeCycleState();
}

class FilePlayerLifeCycle extends PlayerLifeCycle {

  FilePlayerLifeCycle(String dataSource, String preImageSource,
      VideoWidgetBuilder childBuilder, File file)
      : super(childBuilder, dataSource, preImageSource, file);


  @override
  _FilePlayerLifeCycleState createState() => _FilePlayerLifeCycleState();
}

abstract class _PlayerLifeCycleState extends State<PlayerLifeCycle> {
  VideoPlayerController controller;
  bool isinit = false;

  @override

  /// Subclasses should implement [createVideoPlayerController], which is used
  /// by this method.
  void initState() {
    super.initState();
    controller = createVideoPlayerController();
//    controller.addListener(() {
//      if (controller.value.hasError) {
////        print(controller.value.errorDescription);
//      }
//    });
    try {
      print("video player init start " +
          new DateTime.now().millisecondsSinceEpoch.toString());
      controller.initialize().then((onValue) {
        print("video player init success " +
            new DateTime.now().millisecondsSinceEpoch.toString());
        setState(() {
          isinit = true;
        });
      });
    } catch (exception) {
      print("error");
      print(exception.toString());
    }

//    controller.setLooping(true);
    controller.play();
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      child: new Stack(
        children: <Widget>[
          widget.childBuilder(context, controller),
          new Offstage(
            child: Stack(
              children: <Widget>[
                new Center(
                    child: Hero(
                      tag: widget.preImageSource, child: new CachedNetworkImage(
                      imageUrl: widget.preImageSource,
                    ),)
                ),
                Center(child: new CupertinoActivityIndicator(radius: 24.0),)
              ],
            ),
            offstage: isinit,
          ),
        ],
      ),
    );
  }

  VideoPlayerController createVideoPlayerController();
}

class _NetworkPlayerLifeCycleState extends _PlayerLifeCycleState {
  @override
  VideoPlayerController createVideoPlayerController() {
    print(widget.dataSource);
    return VideoPlayerController.network(widget.dataSource);
  }
}

class _AssetPlayerLifeCycleState extends _PlayerLifeCycleState {
  @override
  VideoPlayerController createVideoPlayerController() {
    return VideoPlayerController.asset(widget.dataSource);
  }
}

class _FilePlayerLifeCycleState extends _PlayerLifeCycleState {
  _FilePlayerLifeCycleState();

  @override
  VideoPlayerController createVideoPlayerController() {
    return VideoPlayerController.file(widget.file);
  }
}
/// A filler card to show the video in a list of scrolling contents.


class AspectRatioVideo extends StatefulWidget {
  final VideoPlayerController controller;

  AspectRatioVideo(this.controller);

  @override
  AspectRatioVideoState createState() => AspectRatioVideoState();
}

class AspectRatioVideoState extends State<AspectRatioVideo> {
  VideoPlayerController get controller => widget.controller;
  bool initialized = false;

  VoidCallback listener;

  @override
  void initState() {
    super.initState();
    listener = () {
      if (!mounted) {
        return;
      }
      if (initialized != controller.value.initialized) {
        initialized = controller.value.initialized;
        setState(() {});
      }
    };
    controller.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    if (initialized) {
      final Size size = controller.value.size;
      return Center(
        child: AspectRatio(
          aspectRatio: size.width / size.height,
          child: VideoPlayPause(controller),
        ),
      );
    } else {
      print("black");
      return Container();
    }
  }
}
