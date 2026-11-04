package dev.bhavuk.native_camera_kit

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class NativeCameraKitPluginTest {
    @Test
    fun onMethodCall_unknownMethod_callsNotImplemented() {
        val plugin = NativeCameraKitPlugin()

        val call = MethodCall("unknownMethod", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).notImplemented()
    }
}
