//
//  PersistenceLogger.swift
//  Return Launchpad
//
//  Created for debugging persistence issues
//

import Foundation
import os.log

/// Comprehensive logging system for debugging persistence operations
class PersistenceLogger {
    
    /// Singleton instance for global access
    static let shared = PersistenceLogger()
    
    /// macOS system logger with custom subsystem
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.shorins.return-launchpad", category: "Persistence")
    
    /// Log levels for different types of operations
    enum LogLevel {
        case debug, info, warning, error, critical
    }
    
    /// Initialize console and file logging
    private init() {
        logSystemInfo()
    }
    
    /// Log system information for debugging context
    private func logSystemInfo() {
        log(.info, "=== Return Launchpad Persistence Debug Session Started ===")
        log(.info, "User: \(NSUserName())")
        log(.info, "App Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        log(.info, "App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
        log(.info, "macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        log(.info, "App Path: \(Bundle.main.bundlePath)")
        
        // Check app group availability
        if let appGroupDefaults = UserDefaults(suiteName: "group.shorins.return-launchpad") {
            log(.info, "App Group: Available")
            log(.info, "App Group Keys: \(appGroupDefaults.dictionaryRepresentation().keys.filter { $0.contains("_is") || $0.contains("_user") })")
        } else {
            log(.warning, "App Group: NOT AVAILABLE - falling back to standard UserDefaults")
        }
        
        // Check standard UserDefaults
        let standardKeys = UserDefaults.standard.dictionaryRepresentation().keys.filter { 
            $0.contains("_isCustomOrderEnabled") || $0.contains("_userAppOrder") 
        }
        log(.info, "Standard UserDefaults Keys: \(standardKeys)")
    }
    
    /// Main logging function with different levels
    func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let uniqueTag = "[RLPAD-DEBUG]"
        let fullMessage = "\(uniqueTag) [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)"
        
        // Log to system console (visible in Console.app)
        switch level {
        case .debug:
            logger.debug("\(fullMessage)")
        case .info:
            logger.info("\(fullMessage)")
        case .warning:
            logger.warning("\(fullMessage)")
        case .error:
            logger.error("\(fullMessage)")
        case .critical:
            logger.critical("\(fullMessage)")
        }
        
        // Also print to Xcode console for development with unique prefix
        print("🔍 \(uniqueTag) \(fullMessage)")
    }
    
    /// Log UserDefaults operations with detailed info
    func logUserDefaultsOperation(_ operation: String, key: String, value: Any?, storage: String) {
        var details = "Operation: \(operation), Storage: \(storage), Key: \(key)"
        
        if let value = value {
            if let stringValue = value as? String {
                details += ", Value: \(stringValue.prefix(100))..." // Truncate long JSON
            } else {
                details += ", Value: \(value)"
            }
        }
        
        log(.info, details)
    }
    
    /// Log app lifecycle events
    func logAppLifecycle(_ event: String) {
        log(.info, "🔄 App Lifecycle: \(event)")
    }
    
    /// Log drag & drop operations
    func logDragDrop(_ operation: String, fromIndex: Int? = nil, toIndex: Int? = nil, appName: String? = nil) {
        var details = "🎯 Drag & Drop: \(operation)"
        if let from = fromIndex, let to = toIndex {
            details += " from \(from) to \(to)"
        }
        if let name = appName {
            details += " app '\(name)'"
        }
        log(.info, details)
    }
    
    /// Log data validation results
    func logValidation(_ result: String, issues: [String] = []) {
        log(.info, "✅ Validation: \(result)")
        for issue in issues {
            log(.warning, "⚠️ Validation Issue: \(issue)")
        }
    }
    
    /// Export logs for sharing/analysis
    func exportLogs() -> String {
        return "Logs would be exported here - check Console.app for full logs"
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}