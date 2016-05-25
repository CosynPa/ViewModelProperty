//
//  ViewModelProperty.swift
//  ViewModelProperty
//
//  Created by CosynPa on 5/24/16.
//

import Foundation
import ReactiveCocoa
import Result

public final class ViewModelProperty<Value, UpdateInfo, ActionInfo> {
    public let updateProducer: SignalProducer<(Value, UpdateInfo), NoError>
    public private(set) lazy var noInfoUpdateProducer: SignalProducer<Value, NoError> = self.updateProducer.map { (value, _) in value }
    private let updateObserver: Signal<(Value, UpdateInfo), NoError>.Observer
    
    public let actionSignal: Signal<(Value, ActionInfo), NoError>
    public private(set) lazy var noInfoActionSignal: Signal<Value, NoError> = self.actionSignal.map { (value, _) in value }
    private let actionObserver: Signal<(Value, ActionInfo), NoError>.Observer
    
    private let lock: NSRecursiveLock
    private var _value: Value
    
    public var value: Value {
        get {
            return withValue { $0 }
        }
    }
    
    public private(set) lazy var updateSignal: Signal<(Value, UpdateInfo), NoError> = { [unowned self] in
        var extractedSignal: Signal<(Value, UpdateInfo), NoError>!
        self.updateProducer.startWithSignal { signal, _ in
            extractedSignal = signal
        }
        return extractedSignal
    }()
    
    public init(_ initialValue: Value, info: UpdateInfo) {
        _value = initialValue
        
        lock = NSRecursiveLock()
        lock.name = "org.FU.ViewModelProperty"
        
        (updateProducer, updateObserver) = SignalProducer.buffer(1)
        (actionSignal, actionObserver) = Signal.pipe()
        
        updateObserver.sendNext((initialValue, info))
    }
    
    /// Set the value by program update such as network callback. Returns the old value.
    public func setValueByUpdate(newValue: Value, info: UpdateInfo) -> Value {
        lock.lock()
        defer { lock.unlock() }
        
        let oldValue = _value
        _value = newValue
        updateObserver.sendNext((_value, info))
        return oldValue
    }
    
    /// Set the value by user action, e.g. user edit a text field. Returns the old value.
    public func setValueByAction(newValue: Value, info: ActionInfo) -> Value {
        lock.lock()
        defer { lock.unlock() }
        
        let oldValue = _value
        _value = newValue
        actionObserver.sendNext((_value, info))
        return oldValue
    }
    
    /// Atomically performs an arbitrary action using the current value of the
    /// variable.
    ///
    /// Returns the result of the action.
    public func withValue<Result>(@noescape action: (Value) throws -> Result) rethrows -> Result {
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
    convenience public init(_ initialValue: Value) {
        self.init(initialValue, info: UpdateInfo())
    }
    
    public func setValueByUpdate(newValue: Value) -> Value {
        return setValueByUpdate(newValue, info: UpdateInfo())
    }
}

public extension ViewModelProperty where ActionInfo: NoInfoType {
    public func setValueByAction(newValue: Value) -> Value {
        return setValueByAction(newValue, info: ActionInfo())
    }
}

infix operator <= {
associativity none

// Tighter than assignment but looser than everything else
precedence 93
}

infix operator => {
associativity none

// Tighter than assignment but looser than everything else
precedence 93
}

// These two operators make the direction of data flow clearer.

public func <= <Value, UpdateInfo, ActionInfo>(property: ViewModelProperty<Value, UpdateInfo, ActionInfo>, valueAndInfo: (Value, UpdateInfo)) -> Value {
    return property.setValueByUpdate(valueAndInfo.0, info: valueAndInfo.1)
}

public func => <Value, UpdateInfo, ActionInfo>(valueAndInfo: (Value, ActionInfo), property: ViewModelProperty<Value, UpdateInfo, ActionInfo>) -> Value {
    return property.setValueByAction(valueAndInfo.0, info: valueAndInfo.1)
}

public func <= <Value, UpdateInfo: NoInfoType, ActionInfo>(property: ViewModelProperty<Value, UpdateInfo, ActionInfo>, value: Value) -> Value {
    return property.setValueByUpdate(value, info: UpdateInfo())
}

public func => <Value, UpdateInfo, ActionInfo: NoInfoType>(value: Value, property: ViewModelProperty<Value, UpdateInfo, ActionInfo>) -> Value {
    return property.setValueByAction(value, info: ActionInfo())
}
