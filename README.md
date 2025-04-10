The current project is the merger of anlifecycle and cancelable. The flutter tool includes
cancelable binding of dialog, stream and lifecycle.

## NavigatorState 的扩展

新增一个pushCancellableRoute的扩展，其中Cancellable参数用于取消推入的route，一般用于取消dialog，loading  
也可以使用Context.showCDialog

```
Future<T?> pushCancellableRoute<T extends Object?>(
    Route<T> route, Cancellable? cancellable) 
```

## Lifecycle 的扩展

共同的参数解释  
[runWithDelayed] 延迟一个消息循环执行 可以过滤掉连续的状态变化  
[cancellable] 取消当前的注册block 不再使用和执行  
[block] 当前指定的task 参数cancellable时表示当前的状态是否还满足条

### 构建一个绑定到lifecycle的Cancellable destroy时调用cancel

```
Cancellable makeLiveCancellable({Cancellable? other}) 
```

### 当下一个指定的事件分发时，执行一次给定的block

```
Future<T> launchWhenNextLifecycleEvent<T>(
      {LifecycleEvent targetEvent = LifecycleEvent.start,
      bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) 
      
Future<T> launchWhenNextLifecycleEventStart<T>(
        {bool runWithDelayed = false,
        Cancellable? cancellable,
        required FutureOr<T> Function(Cancellable cancellable) block})
           
Future<T> launchWhenNextLifecycleEventResume<T>(
        {bool runWithDelayed = false,
        Cancellable? cancellable,
        required FutureOr<T> Function(Cancellable cancellable) block})      

Future<T> launchWhenNextLifecycleEventPause<T>(
        {bool runWithDelayed = false,
        Cancellable? cancellable,
        required FutureOr<T> Function(Cancellable cancellable) block})
        
Future<T> launchWhenNextLifecycleEventStop<T>(
        {bool runWithDelayed = false,
        Cancellable? cancellable,
        required FutureOr<T> Function(Cancellable cancellable) block})
    
Future<T> launchWhenLifecycleEventDestroy<T>(
      {bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block})
```

### 当首次高于某个状态时，执行一次给定的block

```
  Future<T> launchWhenLifecycleStateAtLeast<T>(
      {LifecycleState targetState = LifecycleState.started,
      bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block})
      
  Future<T> launchWhenLifecycleStateStarted<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block})
          
  Future<T> launchWhenLifecycleStateResumed<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block})
          
  /// 存在特殊处理 只会执行在State==Destroyed 时
  Future<T> launchWhenLifecycleStateDestroyed<T>(
      {bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block})
```

### 当高于某个状态时执行给定的block 多次重复执行

```
void repeatOnLifecycle<T>(
    {LifecycleState targetState = LifecycleState.started,
    bool runWithDelayed = false,
    Cancellable? cancellable,
    required FutureOr<T> Function(Cancellable cancellable) block})

void repeatOnLifecycleStarted<T>(
        {bool runWithDelayed = false,
        Cancellable? cancellable,
        required FutureOr<T> Function(Cancellable cancellable) block})      
    
void repeatOnLifecycleResumed<T>(
        {bool runWithDelayed = false,
        Cancellable? cancellable,
        required FutureOr<T> Function(Cancellable cancellable) block})      
    
```

### 当高于某个状态时执行给定的block,并将多次执行的结果收集起来为Stream

```
Stream<T> collectOnLifecycle<T>(
    {LifecycleState targetState = LifecycleState.started,
    bool runWithDelayed = false,
    Cancellable? cancellable,
    required FutureOr<T> Function(Cancellable cancellable) block}) 

Stream<T> collectOnLifecycleStarted<T>(
        {bool runWithDelayed = false,
        Cancellable? cancellable,
        required FutureOr<T> Function(Cancellable cancellable) block})

Stream<T> collectOnLifecycleResumed<T>(
        {bool runWithDelayed = false,
        Cancellable? cancellable,
        required FutureOr<T> Function(Cancellable cancellable) block})

```

### 从当前环境中向上寻找特定的 LifecycleOwner

```
LO? findLifecycleOwner<LO extends LifecycleOwner>({bool Function(LO)? test})
```

### extData 寄存于lifecycle的数据

LifecycleExtData 是寄存与设定的lifecycle的数据当lifecycle销毁值自动清空所有

```
/// 判断当前是否是已经销毁状态
bool get isDestroyed => _isDestroyed;

/// 根据Type + key获取，如果不存在则创建信息
T putIfAbsent<T extends Object>(
    {Object? key, required T Function() ifAbsent})

/// 替换为新数据  返回结构为旧数据如果不存在旧数据则返回null
T? replace<T extends Object>({Object? key, required T data})  

/// 根据key获取
T? get<T extends Object>({Object? key})

/// 手动移除指定的key
T? remove<T extends Object>({Object? key}) 

/// 仅在LiveExtData中
/// 根据Type + key获取，如果不存在则创建信息
T getOrPut<T extends Object>(
    {Object? key, required T Function(Lifecycle lifecycle) ifAbsent})
    
/// 仅在LifecycleRegistryExtData中
/// 根据Type + key获取，如果不存在则创建信息
T getOrPut<T extends Object>(
    {Object? key,
    required T Function(ILifecycleRegistry lifecycle) ifAbsent}) 
```

##### extData 子类 LiveExtData 寄存于Lifecycle

```
LiveExtData get extD ata
```

##### ILifecycleRegistry 的扩展 extDataForRegistry 子类 LifecycleRegistryExtData 寄存于ILifecycleRegistry(包含LifecycleOwner)

```
LifecycleRegistryExtData get extDataForRegistry
```

### 直接使用生命周期对对象进行操作

[data]、[factory]、[factory2] 必须其中一个不为空

```
typedef Launcher<T> = FutureOr Function(Lifecycle, T data)

T withLifecycleEffect<T extends Object>({
    T? data,
    T Function()? factory,
    T Function(Lifecycle lifecycle)? factory2,
    Launcher<T>? launchOnFirstCreate,
    Launcher<T>? launchOnFirstStart,
    Launcher<T>? launchOnFirstResume,
    Launcher<T>? repeatOnStarted,
    Launcher<T>? repeatOnResumed,
    Launcher<T>? launchOnDestroy,
  })
```

## 对async中 关联 Lifecycle 的扩展

### 对Steam 将Stream关联到lifecycle

[state] 当大于指定的state时才会继续发送数据  
[closeWhenCancel] 当destroy时 true调回用close false调用cancel

```
  /// 将Stream关联到lifecycle
  /// [repeatLastOnStateAtLeast] 是指当重新进入到状态时，是否发射之前的数据
  Stream<T> bindLifecycle(ILifecycle lifecycle,
      {LifecycleState state = LifecycleState.created,
      bool repeatLastOnStateAtLeast = false,
      bool closeWhenCancel = false,
      bool? cancelOnError})
```

### 对Future 将Future关联到lifecycle

当destroy时自定取消继续传递future

```
  Future<T> bindLifecycle(ILifecycle registry, {bool throwWhenCancel = false})
```

## 对BuildContext中 关联 Lifecycle 的扩展

当前的context会作为key的一部分，即若element发生了变化则会识别为新的作用域

### 从当前的Context中获取最近的Lifecycle并执行相关的任务

```
typedef LLauncher = void Function(Lifecycle lifecycle);

void withLifecycleEffect({
    LLauncher? launchOnFirstCreate,
    LLauncher? launchOnFirstStart,
    LLauncher? launchOnFirstResume,
    LLauncher? repeatOnStarted,
    LLauncher? repeatOnResumed,
    LLauncher? launchOnDestroy,
  }) 
```

### 从当前的Context中获取Lifecycle 并且data 同属于 key的一部分 并执行相关的任务

如果使用factory、factory2 则必须保证多次调用时返回同一值 否则将会视为新建

如果data发生了变化也就意味着新的key 会识别为新的作用域

```
typedef DLauncher<T> = void Function(Lifecycle lifecycle, T data);

T withLifecycleAndDataEffect<T extends Object>({
    T? data,
    T Function()? factory,
    T Function(Lifecycle lifecycle)? factory2,
    DLauncher<T>? launchOnFirstCreate,
    DLauncher<T>? launchOnFirstStart,
    DLauncher<T>? launchOnFirstResume,
    DLauncher<T>? repeatOnStarted,
    DLauncher<T>? repeatOnResumed,
    DLauncher<T>? launchOnDestroy,
    Object? key,
  })
```

## ChangeNotifier 的扩展

### 与 cancellable关联 取消时自动调用dispose

```
T bindCancellable(Cancellable cancellable)
```

### 与lifecycle关联 当lifecycle destroy时调用dispose

```
T bindLifecycle(ILifecycle lifecycle)
```

## Listenable 的扩展

### 增加一个cancellable 当取消时自动取消Listener

```
void addCListener(Cancellable cancellable, VoidCallback listener)
```

### 对注册的listener持唯一性 当多次注册时，数据发生变化时也只会被调用一次

```
void addCSingleListener(Cancellable cancellable, VoidCallback listener)
```

### listener中附带当前的value

```
void addCVListener(Cancellable cancellable, void Function(T value) listener)
```

### 对注册的listener保持唯一性 当多次注册时，数据发生变化时也只会被调用一次。同时listener中附带当前的value

```
void addCSingleVListener(
      Cancellable cancellable, void Function(T value) listener)
```

### 转换为一个stream来处理

```
Stream<T> asStream()
```

### 当value首次满足条件时触发， cancellable 取消时取消监听

```
 Future<T> firstWhereValue(bool Function(T value) test,
      {Cancellable? cancellable})
```

## Additional information

See [anlifecycle](https://pub.dev/packages/anlifecycle)

See [cancelable](https://pub.dev/packages/cancellable)