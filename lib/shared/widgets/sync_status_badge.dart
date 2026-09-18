import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_sync_manager.dart';

class SyncStatusBadge extends ConsumerWidget {
  final bool compact;

  const SyncStatusBadge({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final syncStateAsync = ref.watch(syncStateProvider);

    final isOnline = isOnlineAsync.value ?? ConnectivityService().isOnline;
    final syncState = syncStateAsync.value ?? OfflineSyncManager().state;

    final isSyncing = syncState.status == SyncStatus.syncing;
    final pendingCount = syncState.pendingCount;

    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    if (!isOnline) {
      bgColor = const Color(0xFFFEF3C7); // Amber 100
      textColor = const Color(0xFF92400E); // Amber 800
      icon = Icons.cloud_off_rounded;
      label = pendingCount > 0 ? 'Sin internet ($pendingCount pend.)' : 'Modo Sin Conexión';
    } else if (isSyncing) {
      bgColor = const Color(0xFFE0E7FF); // Indigo 100
      textColor = const Color(0xFF3730A3); // Indigo 800
      icon = Icons.sync_rounded;
      label = pendingCount > 0 ? 'Sincronizando ($pendingCount)...' : 'Sincronizando...';
    } else if (pendingCount > 0) {
      bgColor = const Color(0xFFFFFBEB); // Amber 50
      textColor = const Color(0xFFB45309); // Amber 700
      icon = Icons.cloud_upload_rounded;
      label = '$pendingCount por subir';
    } else {
      bgColor = const Color(0xFFECFDF5); // Emerald 50
      textColor = const Color(0xFF047857); // Emerald 700
      icon = Icons.cloud_done_rounded;
      label = 'En línea';
    }

    if (compact) {
      return Tooltip(
        message: '$label • Toca para sincronizar',
        child: InkWell(
          onTap: () => OfflineSyncManager().syncNow(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: textColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                else
                  Icon(icon, size: 14, color: textColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => OfflineSyncManager().syncNow(),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: textColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            else
              Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (isOnline && pendingCount > 0 && !isSyncing) ...[
              const SizedBox(width: 6),
              Icon(Icons.refresh_rounded, size: 14, color: textColor),
            ],
          ],
        ),
      ),
    );
  }
}

/// Banner global para mostrar en la parte superior cuando se está desconectado
class OfflineGlobalBanner extends ConsumerWidget {
  const OfflineGlobalBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final syncStateAsync = ref.watch(syncStateProvider);

    final isOnline = isOnlineAsync.value ?? ConnectivityService().isOnline;
    final syncState = syncStateAsync.value ?? OfflineSyncManager().state;

    if (isOnline && syncState.pendingCount == 0 && syncState.status != SyncStatus.syncing) {
      return const SizedBox.shrink();
    }

    final isSyncing = syncState.status == SyncStatus.syncing;
    final pending = syncState.pendingCount;

    Color bg = isOnline ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
    String text;

    if (!isOnline) {
      text = pending > 0
          ? 'Estás en modo sin conexión ($pending operaciones guardadas localmente)'
          : 'Estás en modo sin conexión. Los cambios se guardarán localmente.';
    } else if (isSyncing) {
      text = 'Sincronizando $pending registros con la nube...';
    } else {
      text = '$pending registros pendientes de subir a la nube.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: bg,
      child: Row(
        children: [
          Icon(
            !isOnline ? Icons.wifi_off_rounded : Icons.sync_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isOnline && !isSyncing)
            GestureDetector(
              onTap: () => OfflineSyncManager().syncNow(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Sincronizar ahora',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
