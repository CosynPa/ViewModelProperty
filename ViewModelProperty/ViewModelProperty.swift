//
//  ViewModelProperty.swift
//  ViewModelProperty
//
//  Created by CosynPa on 5/24/16.
//

import Foundation
import ReactiveSwift
import Result

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
    public let updateSignal: Signal<(Value, UpdateInfo), NoError>
    private let updateObserver: Signal<(Value, UpdateInfo), NoError>.Observer
    
    public let actionSignal: Signal<(Value, ActionInfo), NoError>
    private let actionObserver: Signal<(Value, ActionInfo), NoError>.Observer
    
    // MARK: - Derived signals
    
    /// Like updateSignal but send current value immediately
    public private(set) lazy var updateProducer: SignalProducer<(Value, CurrentOrUpdate<UpdateInfo>), NoError> = { [unowned self] in
        return SignalProducer { observer, producerDisposable in
            observer.send(value: (self._value, .current))
            
            producerDisposable += self.updateSignal.observeValues { (value, updateInfo) in
                observer.send(value: (value, .update(updateInfo)))
            }
        }
    }()
    
    /// Send current value immediately and send both updates and actions
    public private(set) lazy var allChangeProducer: SignalProducer<(Value, CurrentOrUpdateOrAction<UpdateInfo, ActionInfo>), NoError> = { [unowned self] in
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
    
    public private(set) lazy var noInfoUpdateSignal: Signal<Value, NoError> = self.updateSignal.map { (value, _) in value }
    public private(set) lazy var noInfoActionSignal: Signal<Value, NoError> = self.actionSignal.map { (value, _) in value }
    public private(set) lazy var noInfoUpdateProducer: SignalProducer<Value, NoError> = self.updateProducer.map { (value, _) in value }
    public private(set) lazy var noInfoAllChangeProducer: SignalProducer<Value, NoError> = self.allChangeProducer.map { (value, _) in value }
    
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

public protocol NoInfoType {
    init()
}

public struct NoInfo: NoInfoType {
    public init() {}
}

public extension ViewModelProperty where UpdateInfo: NoInfoType {
    public func setValueByUpdate(_ newValue: Value) -> Value {
        return setValueByUpdate(newValue, info: UpdateInfo())
    }
}

public extension ViewModelProperty where ActionInfo: NoInfoType {
    public func setValueByAction(_ newValue: Value) -> Value {
        return setValueByAction(newValue, info: ActionInfo())
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
public func <+ <Value, UpdateInfo: NoInfoType, ActionInfo>(property: ViewModelProperty<Value, UpdateInfo, ActionInfo>, value: Value) -> Value {
    return property.setValueByUpdate(value, info: UpdateInfo())
}

@discardableResult
public func +> <Value, UpdateInfo, ActionInfo: NoInfoType>(value: Value, property: ViewModelProperty<Value, UpdateInfo, ActionInfo>) -> Value {
    return property.setValueByAction(value, info: ActionInfo())
}
