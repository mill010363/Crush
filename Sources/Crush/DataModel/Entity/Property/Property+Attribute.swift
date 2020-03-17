//
//  Property+Attribute.swift
//  Crush
//
//  Created by ezou on 2019/9/26.
//  Copyright © 2019 ezou. All rights reserved.
//

import CoreData

// MARK: - EntityAttribute

public enum AttributeOption {
    case allowsExternalBinaryDataStorage(Bool)
    case preservesValueInHistoryOnDeletion(Bool)
}

extension AttributeOption: MutablePropertyOptionProtocol {
    public typealias Description = NSAttributeDescription
    
    public func updatePropertyDescription<D: NSPropertyDescription>(_ description: D) {
        guard let description = description as? Description else { return }
        switch self {
        case .allowsExternalBinaryDataStorage(let flag): description.allowsExternalBinaryDataStorage = flag
        case .preservesValueInHistoryOnDeletion(let flag):
            if #available(iOS 13.0, watchOS 6.0, macOS 10.15, *) {
                description.preservesValueInHistoryOnDeletion = flag
            }
        }
    }
}

public protocol AttributeProtocol: NullablePropertyProtocol where PropertyValue: FieldAttributeType {
    var defaultValue: Any? { get set }
    var attributeValueClassName: String? { get }
    var allowsExternalBinaryDataStorage: Bool { get }
    var preservesValueInHistoryOnDeletion: Bool { get }
    init(wrappedValue: PropertyValue, options: [PropertyOptionProtocol])
}

extension AttributeProtocol where EntityType: SavableTypeProtocol {
    public var attributeType: NSAttributeType {
        PropertyValue.nativeType
    }
    
    public var attributeValueClassName: String? {
        EntityType.self is NSCoding.Type ? String(describing: Self.self) : nil
    }
    
    public var valueTransformerName: String? {
        EntityType.self is NSCoding.Type ? String(describing: DefaultTransformer.self) : nil
    }

}

extension AttributeProtocol where EntityType: SavableTypeProtocol {
    public var defaultValue: Any? { nil }
    public var allowsExternalBinaryDataStorage: Bool { false }
    public var preservesValueInHistoryOnDeletion: Bool { false }
    
    public func createDescription<T: NSPropertyDescription>() -> T! {
        let description = NSAttributeDescription()
        
        description.isOptional = isOptional
        description.isTransient = isTransient
        description.userInfo = userInfo
        description.isIndexedBySpotlight = isIndexedBySpotlight
        description.versionHashModifier = versionHashModifier
        description.renamingIdentifier = renamingIdentifier
        description.setValidationPredicates(validationPredicates, withValidationWarnings: validationWarnings)
        
        description.allowsExternalBinaryDataStorage = allowsExternalBinaryDataStorage
        description.defaultValue = defaultValue
        description.valueTransformerName = valueTransformerName
        
        if let className = attributeValueClassName {
            description.attributeValueClassName = className
        }
        
        if #available(iOS 13.0, watchOS 6.0, macOS 10.15, *) {
            description.preservesValueInHistoryOnDeletion = preservesValueInHistoryOnDeletion
        }
        
        return description as? T
    }
}

// MARK: - EntityAttributeType
@propertyWrapper
public final class Attribute<O: OptionalTypeProtocol>: AttributeProtocol where O.FieldType: FieldAttributeType, O.PropertyValue: FieldAttributeType {
    
    public typealias PropertyValue = O.PropertyValue
    public typealias OptionalType = O
    public typealias Option = AttributeOption
    public typealias EntityType = O.FieldType.RuntimeObjectValue
    
    public var wrappedValue: PropertyValue {
        get {
            let value: PropertyValue.ManagedObjectValue = valueMappingProxy!.getValue(property: self)
            return PropertyValue.convert(value: value)
        }
        set {
            guard let proxy = valueMappingProxy as? ReadWriteValueMapperProtocol else {
                return assertionFailure("value should not be modified with read only value mapper")
            }
            let value: PropertyValue.ManagedObjectValue = PropertyValue.convert(value: newValue)
            proxy.setValue(value, property: self)
        }
    }
    
    public var projectedValue: Attribute<O> {
        self
    }
    
    public var valueMappingProxy: ReadOnlyValueMapperProtocol? = nil

    public var name: String?
    
    public var defaultValue: Any? = nil

    public var renamingIdentifier: String?

    public var versionHashModifier: String?
    
    public var userInfo: [AnyHashable : Any]? = [:]

    public lazy var description: NSPropertyDescription! = {
        return self.createDescription()
    }()
    
    public init() {
        updateProperty()
    }
    
    public convenience init(wrappedValue: PropertyValue) {
        self.init(wrappedValue: wrappedValue, options: [])
    }
    
    public init(wrappedValue: PropertyValue, options: [PropertyOptionProtocol]) {
        self.defaultValue = wrappedValue
        self.updateProperty()
        options.forEach{ $0.updatePropertyDescription(description) }
    }
    
    public init(_ defaultValue: String? = nil, options: [PropertyOptionProtocol] = []) {
        self.defaultValue = defaultValue
        self.updateProperty()
        options.forEach{ $0.updatePropertyDescription(description) }
    }
    
    public func updateProperty() {
        guard let description = description as? NSAttributeDescription else { return }
        description.name = name ?? description.name
        description.defaultValue = defaultValue
        description.versionHashModifier = versionHashModifier
        description.renamingIdentifier = renamingIdentifier
        description.isOptional = O.isOptional
        description.attributeType = attributeType
    }
}