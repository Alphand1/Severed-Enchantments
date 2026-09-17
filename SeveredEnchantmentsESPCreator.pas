// This file is an xEdit Skyrim Special Edition script meant to be applied on 
// plugins of your liking in order to create an esp that overrides those armors
// and weapons's plugins. I only used it on base game plugins (Skyrim.esm, 
// Update.esm, Dawnguard.esm, Hearthfires.esm, Dragonborn.esm + all cc content
// plugins) + USSEP

unit SeveredEnchantmentsESPCreator;

const
  TARGET_FILE = 'Severed Enchantments - Artifacts and CC content.esp';
  MAGIC_DISALLOW_ENCHANTING = $000C27BD;

var
  TargetFile: IwbFile;
  ProcessedForms: TStringList;

function IsOfficialFile(aFile: IwbFile): Boolean;
var
  FileName: string;
  BaseName: string;
  Extension: string;
begin
  Result := False;

  if not Assigned(aFile) then
    Exit;

  FileName := LowerCase(GetFileName(aFile));
  BaseName := ChangeFileExt(FileName, '');
  Extension := LowerCase(ExtractFileExt(FileName));

  // Skyrim + DLCs
  if (FileName = 'skyrim.esm') or
     (FileName = 'update.esm') or
     (FileName = 'dawnguard.esm') or
     (FileName = 'hearthfires.esm') or
     (FileName = 'dragonborn.esm') then begin
    Result := True;
    Exit;
  end;

  // Creation Club
  if (Copy(BaseName, 1, 2) = 'cc') and
     ((Extension = '.esl') or (Extension = '.esm')) then begin
    Result := True;
    Exit;
  end;
end;

function HasMagicDisallowEnchanting(aRecord: IInterface): Boolean;
var
  Keywords: IInterface;
  i: Integer;
  Keyword: IInterface;
begin
  Result := False;

  Keywords := ElementByPath(aRecord, 'KWDA');

  if not Assigned(Keywords) then
    Exit;

  for i := 0 to ElementCount(Keywords) - 1 do begin
    Keyword := LinksTo(ElementByIndex(Keywords, i));

    if Assigned(Keyword) then begin
      if GetLoadOrderFormID(Keyword) = MAGIC_DISALLOW_ENCHANTING then begin
        Result := True;
        Exit;
      end;
    end;
  end;
end;

procedure RemoveMagicDisallowEnchanting(aRecord: IInterface);
var
  Keywords: IInterface;
  i: Integer;
  Keyword: IInterface;
begin
  Keywords := ElementByPath(aRecord, 'KWDA');

  if not Assigned(Keywords) then
    Exit;

  for i := ElementCount(Keywords) - 1 downto 0 do begin
    Keyword := LinksTo(ElementByIndex(Keywords, i));

    if Assigned(Keyword) then begin
      if GetLoadOrderFormID(Keyword) = MAGIC_DISALLOW_ENCHANTING then begin
        AddMessage(
          '[KWDA] Removing MagicDisallowEnchanting in ' +
          Name(aRecord)
        );

        Remove(ElementByIndex(Keywords, i));
      end;
    end;
  end;
end;

function GetEditorID(aRecord: IInterface): string;
begin
  Result := GetElementEditValues(aRecord, 'EDID');
end;

function AlreadyProcessed(aRecord: IInterface): Boolean;
var
  ID: string;
begin
  ID := IntToHex(GetLoadOrderFormID(aRecord), 8);

  Result := ProcessedForms.IndexOf(ID) >= 0;

  if not Result then
    ProcessedForms.Add(ID);
end;

function FindExistingADRecord(EditorID: string): IInterface;
var
  Group: IInterface;
  i: Integer;
  RecordElement: IInterface;
  EDID: string;
begin
  Result := nil;

  Group := GroupBySignature(TargetFile, 'WEAP');

  if Assigned(Group) then begin
    for i := 0 to ElementCount(Group) - 1 do begin
      RecordElement := ElementByIndex(Group, i);
      EDID := GetElementEditValues(RecordElement, 'EDID');

      if SameText(EDID, EditorID) then begin
        Result := RecordElement;
        Exit;
      end;
    end;
  end;

  Group := GroupBySignature(TargetFile, 'ARMO');

  if Assigned(Group) then begin
    for i := 0 to ElementCount(Group) - 1 do begin
      RecordElement := ElementByIndex(Group, i);
      EDID := GetElementEditValues(RecordElement, 'EDID');

      if SameText(EDID, EditorID) then begin
        Result := RecordElement;
        Exit;
      end;
    end;
  end;
end;

procedure AddMastersForRecord(aRecord: IInterface);
var
  Masters: TStringList;
  i: Integer;
  SourceFile: string;
begin
  if not Assigned(aRecord) then
    Exit;

  // Adding file to contain records.
  SourceFile := GetFileName(GetFile(aRecord));

  AddMessage('[MASTER] Ajout de ' + SourceFile);
  AddMasterIfMissing(TargetFile, SourceFile, False);

  // Adding all record required masters.
  Masters := TStringList.Create;

  try
    ReportRequiredMasters(aRecord, Masters, True, False);
    AddMessage('[MASTER] Number of detected masters : ' + IntToStr(Masters.Count));

    for i := 0 to Masters.Count - 1 do begin
      if not SameText(Masters[i], SourceFile) then begin
        AddMessage('[MASTER] Required : ' + Masters[i]);
        AddMasterIfMissing(TargetFile, Masters[i], False);
      end;
    end;
  finally
    Masters.Free;
  end;

  // Also makes sure that source file itself has its own masters available.
  AddMasterIfMissing(
    TargetFile,
    GetFileName(GetFile(aRecord)),
    False
  );
end;

procedure CreateArtifact(aOfficialRecord: IInterface);
var
  Winning: IInterface;
  OverrideRecord: IInterface;
  ADRecord: IInterface;
  OriginalEditorID: string;
  NewEditorID: string;
  ExistingAD: IInterface;
begin
  if AlreadyProcessed(aOfficialRecord) then
    Exit;

  if not HasMagicDisallowEnchanting(aOfficialRecord) then
    Exit;

  OriginalEditorID := GetEditorID(aOfficialRecord);

  if OriginalEditorID = '' then begin
    AddMessage(
      '[ERROR] No EditorID for ' +
      Name(aOfficialRecord)
    );
    Exit;
  end;

  NewEditorID := 'AD_' + OriginalEditorID;

  Winning := WinningOverride(aOfficialRecord);

  if not Assigned(Winning) then begin
    AddMessage(
      '[ERROR] Impossible to find WinningOverride for ' +
      Name(aOfficialRecord)
    );
    Exit;
  end;

  AddMessage('');
  AddMessage('==============================================');
  AddMessage('Processing: ' + Name(aOfficialRecord));
  AddMessage('EditorID : ' + OriginalEditorID);
  AddMessage('Winning  : ' + GetFileName(GetFile(Winning)));
  AddMessage('AD ID    : ' + NewEditorID);

  AddMastersForRecord(Winning);

  AddMessage(
    '[MASTER] Adding source file : ' +
    GetFileName(GetFile(aOfficialRecord))
  );

  AddMasterIfMissing(
    TargetFile,
    GetFileName(GetFile(aOfficialRecord)),
    False
  );

  OverrideRecord := wbCopyElementToFile(
    Winning,
    TargetFile,
    False,
    True
  );

  if not Assigned(OverrideRecord) then begin
    AddMessage('[ERROR] Override record creation failed.');
    Exit;
  end;

  // Only removes MagicDisallowEnchanting.
  RemoveMagicDisallowEnchanting(OverrideRecord);

  AddMessage(
    '[OK] Override record created and MagicDisallowEnchanting removed.'
  );

  ExistingAD := FindExistingADRecord(NewEditorID);

  if Assigned(ExistingAD) then begin
    AddMessage(
      '[INFO] AD record already exists : ' +
      NewEditorID
    );
    Exit;
  end;

  ADRecord := wbCopyElementToFile(
    OverrideRecord,
    TargetFile,
    True,
    True
  );

  if not Assigned(ADRecord) then begin
    AddMessage(
      '[ERROR] AD record creation failed.'
    );
    Exit;
  end;

  // Changes EditorID.
  SetElementEditValues(
    ADRecord,
    'EDID',
    NewEditorID
  );

  // Removes enchantment.
  RemoveElement(ADRecord, 'EITM');
  RemoveElement(ADRecord, 'EAMT');

  AddMessage(
    '[OK] Record created : ' +
    NewEditorID
  );

  AddMessage('==============================================');
end;

procedure ScanGroup(aGroup: IInterface);
var
  i: Integer;
  RecordElement: IInterface;
begin
  if not Assigned(aGroup) then
    Exit;

  for i := 0 to ElementCount(aGroup) - 1 do begin
    RecordElement := ElementByIndex(aGroup, i);

    if not Assigned(RecordElement) then
      Continue;

    CreateArtifact(RecordElement);
  end;
end;

procedure ScanFile(aFile: IwbFile);
var
  WEAPGroup: IInterface;
  ARMOGroup: IInterface;
begin
  if not IsOfficialFile(aFile) then
    Exit;

  AddMessage('');
  AddMessage('----------------------------------------------');
  AddMessage('Scanning : ' + GetFileName(aFile));
  AddMessage('----------------------------------------------');

  WEAPGroup := GroupBySignature(aFile, 'WEAP');

  if Assigned(WEAPGroup) then
    ScanGroup(WEAPGroup);

  ARMOGroup := GroupBySignature(aFile, 'ARMO');

  if Assigned(ARMOGroup) then
    ScanGroup(ARMOGroup);
end;

function Initialize: Integer;
var
  i: Integer;
  FileElement: IwbFile;
begin
  AddMessage('==============================================');
  AddMessage(' Severed Enchantments - Artifact and CC content creator');
  AddMessage('==============================================');

  ProcessedForms := TStringList.Create;

  // Find of create the ESP.
  TargetFile := FileByName(TARGET_FILE);

  if not Assigned(TargetFile) then begin
    AddMessage('');
    AddMessage('[INFO] Creation of ' + TARGET_FILE);
    TargetFile := AddNewFileName(TARGET_FILE);
  end;

  if not Assigned(TargetFile) then begin
    AddMessage('[ERROR] Target plugin creation failed.');
    Result := 1;
    Exit;
  end;

  AddMessage('');
  AddMessage('Target file : ' + GetFileName(TargetFile));
  AddMessage('');

  // Browse all loaded files.
  for i := 0 to FileCount - 1 do begin
    FileElement := FileByIndex(i);
    ScanFile(FileElement);
  end;

  AddMessage('');
  AddMessage('==============================================');
  AddMessage(' Creation Done.');
  AddMessage('==============================================');

  Result := 0;
end;

function Process(e: IInterface): Integer;
begin
  // Script browses files itself.
  Result := 0;
end;

function Finalize: Integer;
begin
  if Assigned(ProcessedForms) then
    ProcessedForms.Free;

  Result := 0;
end;

end.
