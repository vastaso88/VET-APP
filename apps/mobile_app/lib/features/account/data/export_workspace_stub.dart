import 'export_workspace.dart';

/// The web: no disk, the files stay in memory.
Future<ExportWorkspace> createExportWorkspace() async => MemoryExportWorkspace();
