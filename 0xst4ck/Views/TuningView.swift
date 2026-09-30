import SwiftUI

struct TuningView: View {
    @EnvironmentObject var ble: BLEManager

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                sectionTitle("SPEED / POWER")
                speedLimitCard
                strongLimitCard
                wheelSizeCard

                sectionTitle("MOTOR PROFILE")
                motorCard

                sectionTitle("FLAGS")
                flagsCard

                sectionTitle("AUTH")
                authCard

                pushButton
            }
            .padding(16)
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        HStack {
            Text(t).font(Theme.monoSmall).foregroundColor(Theme.textDim)
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
    }

    private var speedLimitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("speed_limit").font(Theme.mono)
                Spacer()
                Text("\(ble.scooter.params.speedLimit) km/h")
                    .font(Theme.mono)
                    .foregroundColor(ble.scooter.params.speedLimit > 28 ? Theme.warn : Theme.accent)
            }
            Slider(value: Binding(
                get: { Double(ble.scooter.params.speedLimit) },
                set: { ble.scooter.params.speedLimit = UInt8(clamping: Int($0)) }
            ), in: 0...80, step: 1)
            Text("stock UI clamp: 20/22/25/28. this slider is unclamped (byte 0-255).")
                .font(Theme.monoSmall).foregroundColor(Theme.textDim)
        }
        .cardBg()
    }

    private var strongLimitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("strong_limit").font(Theme.mono)
                Spacer()
                Text("\(ble.scooter.params.strongLimit)")
                    .font(Theme.mono)
                    .foregroundColor(ble.scooter.params.strongLimit > 5 ? Theme.warn : Theme.accent)
            }
            Slider(value: Binding(
                get: { Double(ble.scooter.params.strongLimit) },
                set: { ble.scooter.params.strongLimit = UInt8(clamping: Int($0)) }
            ), in: 0...15, step: 1)
            Text("torque/current cap. stock: 1-5. behavior above 5 unknown.")
                .font(Theme.monoSmall).foregroundColor(Theme.textDim)
        }
        .cardBg()
    }

    private var wheelSizeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("wheel_size").font(Theme.mono)
                Spacer()
                Text("\(Double(ble.scooter.params.wheelSize)/10.0, specifier: "%.1f")\"")
                    .font(Theme.mono).foregroundColor(Theme.accent)
            }
            Slider(value: Binding(
                get: { Double(ble.scooter.params.wheelSize) },
                set: { ble.scooter.params.wheelSize = UInt8(clamping: Int($0)) }
            ), in: 60...160, step: 5)
            Text("diameter in tenths of an inch. affects displayed speed calibration.")
                .font(Theme.monoSmall).foregroundColor(Theme.textDim)
        }
        .cardBg()
    }

    private var motorCard: some View {
        VStack(spacing: 10) {
            stepper("battery_num", value: $ble.scooter.params.batteryNum, range: 0...20)
            stepper("pole_num",    value: $ble.scooter.params.poleNum,    range: 0...60)
            stepper("pole_num2",   value: $ble.scooter.params.poleNum2,   range: 0...60)
        }
        .cardBg()
    }

    private var flagsCard: some View {
        VStack(spacing: 6) {
            flagToggle("mph",         mask: .mph)
            flagToggle("nonzero_start", mask: .nonZero)
            flagToggle("cruise",      mask: .cruise)
            flagToggle("speed_limit", mask: .speedLimit)
        }
        .cardBg()
    }

    private func flagToggle(_ label: String, mask: FrameFlags) -> some View {
        Toggle(isOn: Binding(
            get: { ble.scooter.params.flags.contains(mask) },
            set: { on in
                if on { ble.scooter.params.flags.insert(mask) }
                else { ble.scooter.params.flags.remove(mask) }
            }
        )) {
            Text(label).font(Theme.mono)
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
    }

    private var authCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("master_pass").font(Theme.monoSmall).foregroundColor(Theme.textDim)
                Spacer()
                TextField("0000", text: $ble.scooter.masterPass)
                    .keyboardType(.numberPad)
                    .font(Theme.mono)
                    .foregroundColor(Theme.accent)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("guest_pass").font(Theme.monoSmall).foregroundColor(Theme.textDim)
                Spacer()
                TextField("000000", text: $ble.scooter.guestPass)
                    .keyboardType(.numberPad)
                    .font(Theme.mono)
                    .foregroundColor(Theme.accent)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("slave_derived").font(Theme.monoSmall).foregroundColor(Theme.textDim)
                Spacer()
                Text(SlavePassword.derive(from: ble.scooter.masterPass))
                    .font(Theme.mono).foregroundColor(Theme.cyan)
            }
            Button("send auth") { ble.sendAuth() }
                .buttonStyle(SmallActionButtonStyle())
        }
        .cardBg()
    }

    private var pushButton: some View {
        Button(action: { ble.sendConfig(tag: "manual-push") }) {
            HStack {
                Image(systemName: "paperplane.fill")
                Text("PUSH CONFIG").font(Theme.mono.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accent.opacity(0.15))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent, lineWidth: 1.5))
            .cornerRadius(12)
            .foregroundColor(Theme.accent)
        }
    }

    private func stepper(_ label: String, value: Binding<UInt8>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label).font(Theme.mono)
            Spacer()
            Stepper(value: Binding(
                get: { Int(value.wrappedValue) },
                set: { value.wrappedValue = UInt8(clamping: $0) }
            ), in: range) {
                Text("\(value.wrappedValue)")
                    .font(Theme.mono)
                    .foregroundColor(Theme.accent)
            }
        }
    }
}

struct SmallActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.monoSmall)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent))
            .cornerRadius(6)
            .foregroundColor(Theme.accent)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
