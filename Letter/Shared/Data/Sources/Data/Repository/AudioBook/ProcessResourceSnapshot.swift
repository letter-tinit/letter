#if DEBUG
import Darwin
import Foundation

struct ProcessResourceSnapshot: Sendable {
    let cpuSeconds: TimeInterval
    let physicalFootprintBytes: UInt64?
    let peakPhysicalFootprintBytes: UInt64?
    let thermalState: String
    let isLowPowerModeEnabled: Bool

    static func capture() -> ProcessResourceSnapshot {
        let memory = memoryUsage()
        return ProcessResourceSnapshot(
            cpuSeconds: processCPUSeconds(),
            physicalFootprintBytes: memory.current,
            peakPhysicalFootprintBytes: memory.peak,
            thermalState: thermalStateName(ProcessInfo.processInfo.thermalState),
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    func summary(
        since start: ProcessResourceSnapshot,
        elapsedSeconds: TimeInterval
    ) -> String {
        let consumedCPUSeconds = max(0, cpuSeconds - start.cpuSeconds)
        let averageCPUPercentage = elapsedSeconds > 0
            ? consumedCPUSeconds / elapsedSeconds * 100
            : 0
        var fields = [
            String(
                format: "process_cpu=%.3fs avg_cpu=%.0f%%",
                consumedCPUSeconds,
                averageCPUPercentage
            )
        ]
        if let before = start.physicalFootprintBytes,
           let after = physicalFootprintBytes {
            fields.append(
                String(
                    format: "phys_footprint=%.1f->%.1fMB delta=%+.1fMB",
                    megabytes(before),
                    megabytes(after),
                    megabytes(after) - megabytes(before)
                )
            )
        }
        if let peakPhysicalFootprintBytes {
            fields.append(
                String(
                    format: "process_peak=%.1fMB",
                    megabytes(peakPhysicalFootprintBytes)
                )
            )
        }
        fields.append("thermal=\(thermalState)")
        fields.append("low_power=\(isLowPowerModeEnabled ? "on" : "off")")
        return fields.joined(separator: " ")
    }

    private static func processCPUSeconds() -> TimeInterval {
        var clock = timespec()
        guard clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &clock) == 0 else {
            return 0
        }
        return TimeInterval(clock.tv_sec) + TimeInterval(clock.tv_nsec) / 1_000_000_000
    }

    private static func memoryUsage() -> (current: UInt64?, peak: UInt64?) {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size /
            MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    rebound,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return (nil, nil) }
        let peak = info.ledger_phys_footprint_peak > 0
            ? UInt64(info.ledger_phys_footprint_peak)
            : UInt64(info.resident_size_peak)
        return (UInt64(info.phys_footprint), peak)
    }

    private static func thermalStateName(
        _ state: ProcessInfo.ThermalState
    ) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }

    private func megabytes(_ bytes: UInt64) -> Double {
        Double(bytes) / 1_048_576
    }
}
#endif
