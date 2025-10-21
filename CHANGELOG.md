## 2.5.1

* Fixed a bug in the Lifecycle.whenLifecycleStateResumed function

## 2.5.0

* Add collectAsState extension function to Stream and Future.
* Added a key parameter to withLifecycleEffect.

## 2.4.3

* Mark remember as deprecated, it will become a standalone library in the future.

## 2.4.2

* Change the manager related to LifecycleObserver to use weak references for ILifecycle.

## 2.4.1

* Add onDispose callback uniformly to rememberXXX.
* ILifecycle.makeLiveCancellable() manager use weak references.

## 2.4.0

* Added a remember extension on BuildContext
* Add CancellableValueNotifier.

## 2.3.3

* Change the listener in Stream.repeatLatest from closeSync to close.

## 2.3.2

* Fix the determination of whether the route is active when canceling pushCancellableRoute.

## 2.3.1

* Upgrade dependencies.

## 2.3.0+1

* Fix changelog display error.

## 2.3.0

* Adjust the parameters of Stream.bindLifecycle.

### Breaking Changes

* In Stream.bindLifecycle,
  The parameter repeatLastOnRestart is deprecated.
  A new parameter repeatLastOnStateAtLeast.
  The default value of the state parameter is changed from LifecycleState.started to
  LifecycleState.created, aligning with the behavior of other bind methods.

## 2.2.1

* Fix the bug of repeatLatest done.

## 2.2.0

* The repeatOnLifecycle and collectOnLifecycle functions are extended to support error handling for
  the execution block via a new parameter called ignoreBlockError.
  By default, ignoreBlockError is set to false, meaning any errors occurring in the block will be
  reported using FlutterError.reportError.
* In the extension functions withLifecycleEffect and withLifecycleAndDataEffect, if an exception
  occurs in the execution units, FlutterError.reportError will be called.
* ILifecycle adds new extensions: whenLifecycleStateAtLeast, whenLifecycleStateXXX,
  whenLifecycleNextEvent, whenLifecycleNextEventXXX. These methods return a Future<Cancellable>,
  making them convenient for use in asynchronous operations.

## 2.1.0

* Refine the timing checks for the withLifecycle launch methods.
* BuildContext.withLifecycleEffectData will be renamed to BuildContext.withLifecycleAndDataEffect.
* ILifecycle adds a new tickerProvider extension.
* BuildContext adds new extensions: withLifecycleExtData and withLifecycleAndExtDataEffect.

## 2.0.2

* LifecycleExtData adds a check to verify if it has been destroyed.

## 2.0.1

* Fix the bug in Stream.repeatLatest.

## 2.0.0

* Stream adds extension onData, repeatLatest.
* BuildContext adds extensions withLifecycleEffect, withLifecycleEffectData.

### Breaking Changes

* LifecycleExtData is subdivided into LiveExtData and LifecycleRegistryExtData.
* LifecycleExtData will automatically generate a Key based on the Type, and all parameters in the
  methods will be changed to named parameters.

## 1.1.0

* Upgrading Dependencies.
* lifecycleExtData renamed to extData.
* Added extDataForRegistry.

## 1.0.2

* The newly added findLifecycleOwner can be used to search upward for the specified LifecycleOwner.

## 1.0.1

* After upgrading lifecycle to 3.0, some assertions are abnormal

## 1.0.0

* Lifecycle upgraded to 3.0.0

## 0.0.7

* Continue to expand the launch series
* Fix reference exception caused by makeLiveCancellable

## 0.0.6

* Continue to expand the launch series
* fix withLifecycleEffect bugs
* fix lifecycleExtData bugs

## 0.0.5

* Postpone the execution of resumed of withLifecycleEffect (wait for the next event loop)
* fix withLifecycleEffect assert judgment error

## 0.0.4+1

* Fix lifecycleExtData automatic cleanup exception

## 0.0.4

* Migration of Listenable extensions.
* Adding a new launch to the lifecycle (executed only once).
* Added extension lifecycleExtData, which can store data based on the lifecycle and automatically
  clean it up upon destroy.

## 0.0.3

* fix bug whenMoreThanState

## 0.0.2

* export dialog/dialog_ext.dart

## 0.0.1

* The first version migration is completed
