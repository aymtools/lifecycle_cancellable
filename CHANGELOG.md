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
