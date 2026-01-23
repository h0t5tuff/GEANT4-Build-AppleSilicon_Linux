#include "RMGHardware.hh"
#include "RMGLog.hh"
#include "RMGManager.hh"

#include "G4UIExecutive.hh"
#include "G4UImanager.hh"

int main(int argc, char **argv)
{

  // RMGLog::SetLogLevel(RMGLog::debug);

  RMGManager manager("01-gdml", argc, argv);
  manager.GetDetectorConstruction()->IncludeGDMLFile("gdml/main.gdml");

  std::string macro = argc > 1 ? argv[1] : "";

  // Always initialize Geant4 first
  manager.Initialize();

  if (!macro.empty())
  {
    manager.IncludeMacroFile(macro);
    manager.Run();
    return 0;
  }

  // No macro: start interactive UI (Qt if available)
  G4UIExecutive ui(argc, argv, "qt");
  // Optionally: open a default vis macro here if you want:
  // G4UImanager::GetUIpointer()->ApplyCommand("/control/execute vis-cutaway.mac");

  ui.SessionStart();
  return 0;
}