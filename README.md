# Windowed

**Windowed** is an iOS touch controller companion and macOS system control ecosystem. It turns your iPhone into a rich tactile control deck for your Mac, offering instant app switching, window snapping presets, media controls, multi-touch gestures, and remote shortcuts over local Bonjour networking.

## Features

- 📱 **Customizable Shortcut Grid**: Launch macOS applications, run system shortcuts, open websites, and type emojis with liquid glass visual feedback.
- 🗂 **Window Switcher & Snapping**: Real-time macOS window discovery and tactile layout blueprints (Full Screen, Left/Right Split, Quarters, Center).
- 🎵 **Dynamic Music Island**: Auto-shrinking media bar displaying current track info, album art, playback controls, volume, and brightness sliders.
- 🖐 **Multi-Touch Native Gestures**:
  - 3-Finger horizontal swipe: Switch macOS Spaces / Mission Control desktops.
  - 4-Finger horizontal swipe: Seamless remote Clipboard Copy & Paste.
  - 2-Finger Pinch In / Out: Minimize & Maximize windows.
- ⚡ **Local Bonjour & Frame-Based Protocol**: Zero-cloud, low-latency length-prefixed binary framing over local TCP.

## Architecture

- **`Windowed/`**: iOS client built with SwiftUI, Observation, Network framework, and UIKit haptics.
- **`WindowedCompanion/`**: macOS menu bar helper built with AppKit, `NSWorkspace`, Accessibility API (`AXUIElement`), and `CoreGraphics`.

## Requirements

- **iOS Client**: iOS 17.0+
- **macOS Companion**: macOS 14.0+ (Requires Accessibility permissions in System Settings)

## Instalación y uso

Guía paso a paso para compilar, instalar y ejecutar Windowed en dispositivos físicos reales usando una cuenta de Apple ID gratuita (sin necesidad de cuenta de pago de Apple Developer).

### 1. Clonar el repositorio

```bash
git clone https://github.com/Mateodans/Windowed.git
cd Windowed
```

### 2. Ejecutar Windowed Companion en la Mac

1. Abrir `WindowedCompanion.xcodeproj` en Xcode.
2. Seleccionar el target **WindowedCompanion** y entrar en la pestaña **Signing & Capabilities**.
3. En el campo **Team**, seleccionar tu **Apple ID personal** (Personal Team). No se requiere cuenta de pago.
4. Presionar `Product → Run` (o `⌘R`) para compilar y ejecutar.
5. La aplicación se iniciará como un ícono residente en la barra de menú superior de macOS.

### 3. Otorgar permisos de Accesibilidad en macOS

Para permitir que el Companion organice, enfoque y redimensione ventanas mediante la API de Accesibilidad (`AXUIElement`):

1. Abrir **Ajustes del Sistema → Privacidad y Seguridad → Accesibilidad**.
2. En la lista de aplicaciones, activar el switch para **Windowed Companion**.
3. Si la app ya estaba abierta, reiniciar el companion para asegurar que macOS registre los nuevos permisos.

### 4. Instalar Windowed en el iPhone

1. Conectar el iPhone a la Mac mediante cable USB / Lightning.
2. Abrir `Windowed.xcodeproj` en Xcode.
3. En el selector de dispositivo (barra superior de Xcode), seleccionar tu **iPhone físico** en lugar de un simulador.
4. En el target **Windowed**, ir a **Signing & Capabilities** y seleccionar el mismo **Personal Team** (Apple ID).
   > *Nota:* Si Xcode indica conflicto de Bundle Identifier, cambiar `com.windowed.app` por uno personalizado (ej. `com.tuusuario.windowed`).
5. Presionar `Product → Run` (`⌘R`) para compilar e instalar la app en el dispositivo.

### 5. Confiar en el certificado de desarrollador (primera vez)

La primera vez que instales una app firmada con tu Apple ID personal, iOS bloqueará su apertura indicando *"Desarrollador no confiable"*:

1. En el iPhone, ir a **Ajustes → General → VPN y gestión de dispositivos**.
2. En la sección **App de desarrollador**, tocar sobre tu Apple ID.
3. Tocar **Confiar en "[Tu Apple ID]"** y confirmar la acción.
4. Abrir la app **Windowed** desde la pantalla de inicio del iPhone.

### 6. Emparejar iPhone y Mac

1. Verificar que tanto la Mac como el iPhone estén conectados a la **misma red Wi-Fi** local.
2. Hacer clic en el ícono de **Windowed Companion** en la barra de menú de la Mac para ver el **código de emparejamiento de 6 dígitos**.
3. Abrir **Windowed** en el iPhone: la app descubrirá el Mac automáticamente mediante Bonjour.
4. Ingresar el código de 6 dígitos y presionar **Conectar**.

---

> [!WARNING]
> ### ⚠️ Limitación de firma con cuenta gratuita de Apple ID (7 días)
> Los perfiles de aprovisionamiento generados con cuentas gratuitas de Apple ID expiran automáticamente a los **7 días**. Cumplido ese plazo, iOS impedirá abrir la app en el iPhone mostrando un error de perfil expirado.
> 
> - **Para renovar el acceso:** Volvé a conectar el iPhone a la Mac con cable, abrí el proyecto en Xcode y ejecutá `Product → Run` (`⌘R`). La app se re-firmará por otros 7 días conservando todos tus atajos, tiles y configuraciones.
> - **Alternativa para firma de 1 año:** Con una membresía activa del **Apple Developer Program** ($99 USD/año), los certificados permanecen vigentes durante 1 año continuo sin necesidad de re-firmar semanalmente.
