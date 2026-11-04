## 0.0.1

* Initial release of `native_camera_kit`.
* Direct low-level sensor access via Android Camera2 and iOS AVFoundation.
* Manual ISO sensitivity and exposure time (shutter speed) controls.
* Manual lens focus distance and animated tap-to-focus / point-of-interest metering.
* Real-time zero-copy raw frame streaming (`YUV_420_888` on Android, `BGRA8888` on iOS) for edge ML and computer vision.
* Hardware texture rendering via Flutter Texture API (`SurfaceTexture` / `FlutterTexture`).
* Exposure compensation (EV bias).
* White balance presets and custom Kelvin temperature configuration.
* Continuous optical and digital zoom control.
* Flash modes and continuous torch brightness control.
* Hardware video stabilization modes (off, standard, cinematic).
* High-resolution JPEG still capture.
* Hardware-encoded MP4 video recording with audio support.
* Comprehensive interactive example app with real-time HUD and manual controls.
