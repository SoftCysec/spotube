import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:platform_ui/platform_ui.dart';
import 'package:spotube/hooks/playback_hooks.dart';
import 'package:spotube/collections/intents.dart';
import 'package:spotube/models/logger.dart';
import 'package:spotube/provider/playback_provider.dart';
import 'package:spotube/utils/primitive_utils.dart';

class PlayerControls extends HookConsumerWidget {
  final Color? iconColor;

  PlayerControls({
    this.iconColor,
    Key? key,
  }) : super(key: key);

  final logger = getLogger(PlayerControls);

  static FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context, ref) {
    final shortcuts = useMemoized(
        () => {
              const SingleActivator(LogicalKeyboardKey.arrowRight):
                  SeekIntent(ref, true),
              const SingleActivator(LogicalKeyboardKey.arrowLeft):
                  SeekIntent(ref, false),
            },
        [ref]);
    final actions = useMemoized(
        () => {
              SeekIntent: SeekAction(),
            },
        []);
    final Playback playback = ref.watch(playbackProvider);

    final onNext = useNextTrack(ref);
    final onPrevious = usePreviousTrack(ref);

    final duration = playback.currentDuration;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (focusNode.canRequestFocus) {
          focusNode.requestFocus();
        }
      },
      child: FocusableActionDetector(
        focusNode: focusNode,
        shortcuts: shortcuts,
        actions: actions,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              StreamBuilder<Duration>(
                stream: playback.player.onPositionChanged,
                builder: (context, snapshot) {
                  final totalMinutes = PrimitiveUtils.zeroPadNumStr(
                      duration.inMinutes.remainder(60));
                  final totalSeconds = PrimitiveUtils.zeroPadNumStr(
                      duration.inSeconds.remainder(60));
                  final currentMinutes = snapshot.hasData
                      ? PrimitiveUtils.zeroPadNumStr(
                          snapshot.data!.inMinutes.remainder(60))
                      : "00";
                  final currentSeconds = snapshot.hasData
                      ? PrimitiveUtils.zeroPadNumStr(
                          snapshot.data!.inSeconds.remainder(60))
                      : "00";

                  final sliderMax = duration.inSeconds;
                  final sliderValue = snapshot.data?.inSeconds ?? 0;

                  return HookBuilder(
                    builder: (context) {
                      final progressStatic =
                          (sliderMax == 0 || sliderValue > sliderMax)
                              ? 0
                              : sliderValue / sliderMax;

                      final progress = useState<num>(
                        useMemoized(() => progressStatic, []),
                      );

                      useEffect(() {
                        progress.value = progressStatic;
                        return null;
                      }, [progressStatic]);

                      return Column(
                        children: [
                          PlatformTooltip(
                            message: "Slide to seek forward or backward",
                            child: PlatformSlider(
                              // cannot divide by zero
                              // there's an edge case for value being bigger
                              // than total duration. Keeping it resolved
                              value: progress.value.toDouble(),
                              onChanged: (v) {
                                progress.value = v;
                              },
                              onChangeEnd: (value) async {
                                await playback.seekPosition(
                                  Duration(
                                    seconds: (value * sliderMax).toInt(),
                                  ),
                                );
                              },
                              activeColor: iconColor,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                PlatformText(
                                  "$currentMinutes:$currentSeconds",
                                ),
                                PlatformText("$totalMinutes:$totalSeconds"),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  PlatformIconButton(
                    tooltip: playback.isLoop
                        ? "Repeat playlist"
                        : playback.isShuffled
                            ? "Loop track"
                            : "Shuffle playlist",
                    icon: Icon(
                      playback.isLoop
                          ? Icons.repeat_one_rounded
                          : playback.isShuffled
                              ? Icons.shuffle_rounded
                              : Icons.repeat_rounded,
                    ),
                    onPressed:
                        playback.track == null || playback.playlist == null
                            ? null
                            : playback.cyclePlaybackMode,
                  ),
                  PlatformIconButton(
                      tooltip: "Previous track",
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        color: iconColor,
                      ),
                      onPressed: () {
                        onPrevious();
                      }),
                  PlatformIconButton(
                    tooltip: playback.isPlaying
                        ? "Pause playback"
                        : "Resume playback",
                    icon: playback.status == PlaybackStatus.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: PlatformCircularProgressIndicator(),
                          )
                        : Icon(
                            playback.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: iconColor,
                          ),
                    onPressed: Actions.handler<PlayPauseIntent>(
                      context,
                      PlayPauseIntent(ref),
                    ),
                  ),
                  PlatformIconButton(
                    tooltip: "Next track",
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: iconColor,
                    ),
                    onPressed: () => onNext(),
                  ),
                  PlatformIconButton(
                    tooltip: "Stop playback",
                    icon: Icon(
                      Icons.stop_rounded,
                      color: iconColor,
                    ),
                    onPressed: playback.track != null
                        ? () async {
                            try {
                              await playback.stop();
                            } catch (e, stack) {
                              logger.e("onStop", e, stack);
                            }
                          }
                        : null,
                  )
                ],
              ),
              const SizedBox(height: 5)
            ],
          ),
        ),
      ),
    );
  }
}