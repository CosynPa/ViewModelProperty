//
//  ViewModelProperty.swift
//  ViewModelProperty
//
//  Created by CosynPa on 5/24/16.
//

import Foundation
import ReactiveSwift

public enum CurrentOrUpdate<UpdateInfo> {
    case current
    case update(UpdateInfo)
}

public enum CurrentOrUpdateOrAction<UpdateInfo, ActionInfo> {
    case current
    case update(UpdateInfo)
    case action(ActionInfo)
}

public final class ViewModelProperty<Value, UpdateInfo, ActionInfo> {
    public let updateSignal: Signal<(Value, UpdateInfo), Never>
    private let updateObserver: Signal<(Value, UpdateInfo), Never>.Observer

    public let actionSignal: Signal<(Value, ActionInfo), Never>
    private let actionObserver: Signal<(Value, ActionInfo), Never>.Observer

    // MARK: - Derived signals

    /// Like updateSignal but send current value immediately
    public private(set) lazy var updateProducer: SignalProducer<(Value, CurrentOrUpdate<UpdateInfo>), Never> = { [unowned self] in
        return SignalProducer { observer, producerDisposable in
            observer.send(value: (self._value, .current))

            producerDisposable += self.updateSignal.observeValues { (value, updateInfo) in
                observer.send(value: (value, .update(updateInfo)))
            }
        }
    }()

    /// Send current value immediately and send both updates and actions
    public private(set) lazy var allChangeProducer: SignalProducer<(Value, CurrentOrUpdateOrAction<UpdateInfo, ActionInfo>), Never> = { [unowned self] in
        return SignalProducer { observer, producerDisposable in
            observer.send(value: (self._value, .current))

            producerDisposable += self.updateSignal.observeValues { (value, updateInfo) in
                observer.send(value: (value, .update(updateInfo)))
            }

            producerDisposable += self.actionSignal.observeValues { (value, actionInfo) in
                observer.send(value: (value, .action(actionInfo)))
            }
        }
    }()

    public private(set) lazy var noInfoUpdateSignal: Signal<Value, Never> = self.updateSignal.map { (value, _) in value }
    public private(set) lazy var noInfoActionSignal: Signal<Value, Never> = self.actionSignal.map { (value, _) in value }
    public private(set) lazy var noInfoUpdateProducer: SignalProducer<Value, Never> = self.updateProducer.map { (value, _) in value }
    public private(set) lazy var noInfoAllChangeProducer: SignalProducer<Value, Never> = self.allChangeProducer.map { (value, _) in value }

    // MARK: -

    private let lock: NSRecursiveLock
    private var _value: Value

    public var value: Value {
        get {
            return withValue { $0 }
        }
    }

    public init(_ initialValue: Value) {
        _value = initialValue

        lock = NSRecursiveLock()
        lock.name = "org.FU.ViewModelProperty"

        (updateSignal, updateObserver) = Signal.pipe()
        (actionSignal, actionObserver) = Signal.pipe()
    }

    /// Set the value by program update such as network callback. Returns the old value.
    @discardableResult
    public func setValueByUpdate(_ newValue: Value, info: UpdateInfo) -> Value {
        lock.lock()
        defer { lock.unlock() }

        let oldValue = _value
        _value = newValue
        updateObserver.send(value: (_value, info))
        return oldValue
    }

    /// Set the value by user action, e.g. user edit a text field. Returns the old value.
    @discardableResult
    public func setValueByAction(_ newValue: Value, info: ActionInfo) -> Value {
        lock.lock()
        defer { lock.unlock() }

        let oldValue = _value
        _value = newValue
        actionObserver.send(value: (_value, info))
        return oldValue
    }

    /// Atomically performs an arbitrary action using the current value of the
    /// variable.
    ///
    /// Returns the result of the action.
    public func withValue<Result>(action: (Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }

        return try action(_value)
    }

    deinit {
        updateObserver.sendCompleted()
        actionObserver.sendCompleted()
    }
}

public struct NoInfo {
    public init() {}
}

public extension ViewModelProperty where UpdateInfo == NoInfo {
    func setValueByUpdate(_ newValue: Value) -> Value {
        return setValueByUpdate(newValue, info: NoInfo())
    }
}

public extension ViewModelProperty where ActionInfo == NoInfo {
    func setValueByAction(_ newValue: Value) -> Value {
        return setValueByAction(newValue, info: NoInfo())
    }
}

infix operator <+ : DefaultPrecedence
infix operator +> : DefaultPrecedence

// These two operators make the direction of data flow clearer.

@discardableResult
public func <+ <Value, UpdateInfo, ActionInfo>(property: ViewModelProperty<Value, UpdateInfo, ActionInfo>, valueAndInfo: (Value, UpdateInfo)) -> Value {
    return property.setValueByUpdate(valueAndInfo.0, info: valueAndInfo.1)
}

@discardableResult
public func +> <Value, UpdateInfo, ActionInfo>(valueAndInfo: (Value, ActionInfo), property: ViewModelProperty<Value, UpdateInfo, ActionInfo>) -> Value {
    return property.setValueByAction(valueAndInfo.0, info: valueAndInfo.1)
}

@discardableResult
public func <+ <Value, ActionInfo>(property: ViewModelProperty<Value, NoInfo, ActionInfo>, value: Value) -> Value {
    return property.setValueByUpdate(value, info: NoInfo())
}

@discardableResult
public func +> <Value, UpdateInfo>(value: Value, property: ViewModelProperty<Value, UpdateInfo, NoInfo>) -> Value {
    return property.setValueByAction(value, info: NoInfo())
}

infix operator ?<+ : DefaultPrecedence
infix operator +>? : DefaultPrecedence

// These two operators are for optional properties

@discardableResult
public func ?<+ <Value, UpdateInfo, ActionInfo>(property: ViewModelProperty<Value, UpdateInfo, ActionInfo>?, valueAndInfo: (Value, UpdateInfo)) -> Value? {
    return property?.setValueByUpdate(valueAndInfo.0, info: valueAndInfo.1)
}

@discardableResult
public func +>? <Value, UpdateInfo, ActionInfo>(valueAndInfo: (Value, ActionInfo), property: ViewModelProperty<Value, UpdateInfo, ActionInfo>?) -> Value? {
    return property?.setValueByAction(valueAndInfo.0, info: valueAndInfo.1)
}

@discardableResult
public func ?<+ <Value, ActionInfo>(property: ViewModelProperty<Value, NoInfo, ActionInfo>?, value: Value) -> Value? {
    return property?.setValueByUpdate(value, info: NoInfo())
}

@discardableResult
public func +>? <Value, UpdateInfo>(value: Value, property: ViewModelProperty<Value, UpdateInfo, NoInfo>?) -> Value? {
    return property?.setValueByAction(value, info: NoInfo())
}
