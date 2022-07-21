class MethodCallHandlerImpl implements MethodCallHandler {

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    if (call.method.equals("toggleProximityListener")) {
      Boolean enabled = (Boolean) call.argument("enabled");
      proximityStreamHandler.setProximityListenerEnabled(enabled);
    } else if (call.method.equals("toggleScreenOnProximityChanged")) {
      Boolean enabled = (Boolean) call.argument("enabled");
      proximityStreamHandler.setToggleScreenOnProximityChanged(enabled);
    } else {
      result.notImplemented();
    }
  }
}
