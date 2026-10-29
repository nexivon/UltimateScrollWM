import AppKit
import SwiftUI

/// `⌥Tab` pencere seçici.
///
/// Windows'taki `Alt+Tab` gibi çalışır:
///   1. `⌥Tab` → panel açılır (liste **bir kez** alınır, minimize pencereler dahil)
///   2. `⌥` basılı tutup `Tab`'a basmaya devam → pencereler arasında gez
///   3. `⌥` bırakılınca → seçim uygulanır (minimize ise geri açılır)
///   4. `Esc` → iptal
@MainActor
final class WindowSwitcherController {
    private weak var engine: StripEngine?
    private var panel: SwitcherPanel?

    /// `⌥` bırakılışını yakalayan genel izleyici (Erişilebilirlik izni gerektirir).
    private var flagsMonitor: Any?
    /// `Esc` ile iptal için genel tuş izleyici.
    private var keyMonitor: Any?
    /// Panel anahtar pencere olduğunda (ör. `✕` tıklandığında) olaylar artık
    /// genel izleyiciye düşmez; bunlar aynı işi yerel olarak yapar.
    private var localFlagsMonitor: Any?
    private var localKeyMonitor: Any?
    /// `⌥` bırakılışı kaçırılırsa panelin takılı kalmasını önleyen emniyet zamanlayıcısı.
    private var safetyWorkItem: DispatchWorkItem?
    private var isActive = false

    init(engine: StripEngine) {
        self.engine = engine
    }

    func showNext() { show(direction: 1) }
    func showPrevious() { show(direction: -1) }

    // MARK: - Oturum

    private func show(direction: Int) {
        guard let engine else { return }

        // Liste YALNIZCA oturum başında alınır. Her basışta yeniden alınırsa
        // seçim gerçek odaktaki pencereye geri sıfırlanır ve gezmek imkânsız olur.
        if !isActive {
            // Pencere listesi boşsa (ekran kilitli, uyku sonrası ilk saniyeler…)
            // oturum AÇILMAZ: bayrak açık kalırsa pencere listesi uygulama
            // yeniden başlatılana kadar donar. Ayrıca yarım kalmış bir panel
            // varsa burada temizlenir.
            guard engine.beginSwitcherSession() else {
                endSession()
                return
            }
            beginSessionIfNeeded()
        }

        if direction > 0 {
            engine.selectNextForSwitcher()
        } else {
            engine.selectPreviousForSwitcher()
        }

        present(engine: engine)
        scheduleSafety()
    }

    /// Seçimi uygular ve paneli kapatır (`⌥` bırakıldığında).
    func commit() {
        guard isActive else { return }
        // Panel ÖNCE kapanır, seçim SONRA uygulanır. `activateSwitcherSelection()`
        // içindeki AX çağrısı (pencereyi öne getirme) yavaşlarsa veya bloklanırsa
        // panelin ekranda takılı kalmasını engeller. Seçim bilgisi oturum
        // verisinde durduğu için sıra değişimi güvenli.
        let engine = self.engine
        endSession()
        engine?.activateSwitcherSelection()
    }

    /// İptal eder, seçimi uygulamaz (`Esc`).
    func cancel() {
        guard isActive else { return }
        endSession()
    }

    private func beginSessionIfNeeded() {
        guard !isActive else { return }
        isActive = true

        // ⌥ bırakılınca onayla.
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard !event.modifierFlags.contains(.option) else { return }
            DispatchQueue.main.async { self?.commit() }
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self, self.isActive else { return event }
            if !event.modifierFlags.contains(.option) { self.commit() }
            return event
        }

        // Esc ile iptal.
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return } // Esc
            DispatchQueue.main.async { self?.cancel() }
        }

        // Panel anahtar pencereyken Esc'i **tüket**: arkadaki uygulamaya gitmesin.
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isActive else { return event }
            guard event.keyCode == 53 else { return event } // Esc
            self.cancel()
            return nil
        }
    }

    /// İzleyici kurulamadıysa (izin yoksa) kısa, kurulduysa uzun bir emniyet
    /// süresi kullan; panel hiçbir durumda ekranda takılı kalmasın.
    private func scheduleSafety() {
        safetyWorkItem?.cancel()
        let delay: TimeInterval = flagsMonitor == nil ? 1.5 : 10.0
        let item = DispatchWorkItem { [weak self] in self?.commit() }
        safetyWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Seçicideki pencereyi kapatır, sonra paneli yeni boyuta göre tazeler.
    private func closeWindow(at index: Int) {
        guard let engine else { return }
        engine.closeSwitcherWindow(at: index)

        if engine.state.windows.isEmpty {
            endSession()
        } else {
            present(engine: engine)
            scheduleSafety()
        }
    }

    private func endSession() {
        isActive = false
        safetyWorkItem?.cancel()
        safetyWorkItem = nil
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let localFlagsMonitor {
            NSEvent.removeMonitor(localFlagsMonitor)
            self.localFlagsMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        panel?.orderOut(nil)
        WindowThumbnailProvider.shared.endSession()
        engine?.endSwitcherSession()
    }

    // MARK: - Panel

    private func present(engine: StripEngine) {
        if panel == nil {
            let hosting = SwitcherHostingView(
                rootView: WindowSwitcherView(
                    engine: engine,
                    onClose: { [weak self] index in self?.closeWindow(at: index) }
                )
            )
            let newPanel = SwitcherPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.level = .statusBar
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            newPanel.isMovable = false
            // Yardımcı panel kuralı: içindeki düğmeler (✕) tıklanabilsin ama
            // uygulama öne gelmesin.
            newPanel.isFloatingPanel = true
            newPanel.becomesKeyOnlyIfNeeded = true
            newPanel.contentView = hosting
            panel = newPanel
        }

        guard let panel, let hosting = panel.contentView else { return }

        let wasVisible = panel.isVisible

        // İçerik boyutu pencere sayısına göre değişir; kendini ölçmesine izin ver.
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width < 1 || size.height < 1 {
            size = hosting.intrinsicContentSize
        }
        // Emniyet: panel hiçbir zaman ekrandan büyük olmasın. İçerik ölçümü
        // beklenmedik bir değer döndürürse (boş liste, düzen hatası) ekranı
        // kaplayan boş bir panel kalmasın.
        if let screen = NSScreen.main {
            size.width = min(size.width, screen.visibleFrame.width - 40)
            size.height = min(size.height, screen.visibleFrame.height - 40)
        }
        panel.setContentSize(size)

        // Panel açıkken yeniden ortalamayalım (kapatma sonrası zıplamasın).
        if !wasVisible, let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            ))
        }
        panel.orderFrontRegardless()
    }
}

/// İçindeki düğmelerin tek tıklamayla çalışması için.
private final class SwitcherHostingView: NSHostingView<WindowSwitcherView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Uygulamayı öne getirmeden anahtar pencere olabilen panel.
private final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
