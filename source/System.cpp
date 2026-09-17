#include "System.h"
#include <string>

RE::TESBoundObject* GetUnenchantedItem(RE::TESBoundObject* a_item)
{
    if (!a_item) {
        return nullptr;
    }

    std::string editorID;

    {
        const auto& [map, lock] = RE::TESForm::GetAllFormsByEditorID();

        if (!map) {
            logs::warn("GetUnenchantedItem: EditorID map is null");
            return nullptr;
        }

        const RE::BSReadLockGuard guard{ lock };

        for (const auto& [id, form] : *map) {
            if (form == a_item) {
                editorID = id.c_str();
                break;
            }
        }
    }

    if (editorID.empty()) {
        logs::warn(
            "GetUnenchantedItem: impossible to find the EditorID of {:08X}",
            a_item->GetFormID());

        return nullptr;
    }

    std::string unenchantedEditorID = "AD_" + editorID;

    logs::info(
        "GetUnenchantedItem: {:08X} '{}' -> find '{}'",
        a_item->GetFormID(),
        editorID,
        unenchantedEditorID);

    auto result =
        RE::TESForm::LookupByEditorID<RE::TESBoundObject>(unenchantedEditorID);

    if (result) {
        logs::info(
            "GetUnenchantedItem: found {:08X} '{}'",
            result->GetFormID(),
            result->GetFormEditorID());
    } else {
        logs::info(
            "GetUnenchantedItem: no version found for '{}'",
            unenchantedEditorID);
    }

    return result;
}

class SystemCallback : public RE::IMessageBoxCallback
{
public:
    SystemCallback() = default;
    ~SystemCallback() override = default;

    void Run(std::uint8_t a_button) override
    {
        const std::int32_t response = static_cast<std::int32_t>(a_button) - 4;
        const auto system = System::GetSingleton();

        if (response == 0) {
            system->RemoveEnchantment(system->GetCurrentEntry());
        }
    }
};

void System::ConstructMessageBox()
{
    const auto factoryManager = RE::MessageDataFactoryManager::GetSingleton();
    const auto strings = RE::InterfaceStrings::GetSingleton();
    const auto gameSettings = RE::GameSettingCollection::GetSingleton();
    const auto sYesText = gameSettings->GetSetting("sYesText");
    const auto sNoText = gameSettings->GetSetting("sNoText");
    const auto sConfirmDisenchant = gameSettings->GetSetting("sConfirmDisenchant");

    if (factoryManager && strings) {
        if (const auto factory = factoryManager->GetCreator<RE::MessageBoxData>(strings->messageBoxData)) {
            if (const auto messageBox = factory->Create()) {
                if (sConfirmDisenchant) {
                    messageBox->bodyText = sConfirmDisenchant->GetString();
                }

                if (sYesText && sNoText) {
                    messageBox->buttonText.push_back(sYesText->GetString());
                    messageBox->buttonText.push_back(sNoText->GetString());
                }

                messageBox->warningType = 10;
                messageBox->callback = RE::BSTSmartPointer<RE::IMessageBoxCallback>{ new SystemCallback() };
                messageBox->buttonPressOffset = 4;

                const auto queue = RE::UIMessageQueue::GetSingleton();
                queue->AddMessage(strings->messageBoxData, RE::UI_MESSAGE_TYPE::kShow, messageBox);
            }
        }
    }
}

auto System::GetCurrentEntry() -> RE::InventoryEntryData*
{
    return currentEntry;
}

void System::SetCurrentEntry(RE::InventoryEntryData* a_entry)
{
    currentEntry = a_entry;
}

auto System::GetExtraHealthList(RE::BSSimpleList<RE::ExtraDataList*>* a_lists) -> RE::ExtraDataList*
{
    if (a_lists) {
        for (const auto& xList : *a_lists) {
            if (xList && xList->GetByType<RE::ExtraHealth>()) {
                return xList;
            }
        }
    }
    return nullptr;
}

void System::RemoveEnchantment(RE::InventoryEntryData* a_entry)
{
    if (a_entry) {
        auto item = a_entry->object;

        if (a_entry->extraLists) {
            for (const auto& xList : *a_entry->extraLists) {
                if (xList) {
                    auto xEnchantment = xList->GetByType<RE::ExtraEnchantment>();

                    if (xEnchantment) {
                        xList->Remove(RE::ExtraDataType::kEnchantment, xEnchantment);
                    }

                    auto xCharge = xList->GetByType<RE::ExtraCharge>();
                    
                    if (xCharge) {
                        xList->Remove(RE::ExtraDataType::kCharge, xCharge);
                    }
                }
            }
        }

        RE::TESBoundObject* templateItem = nullptr;

        if (item && item->IsArmor()) {
            templateItem = item->As<RE::TESObjectARMO>()->templateArmor;
        }

        if (item && item->IsWeapon()) {
            templateItem = item->As<RE::TESObjectWEAP>()->templateWeapon;
        }

        RE::TESBoundObject* unenchantedItem = GetUnenchantedItem(item);

        const auto player = RE::PlayerCharacter::GetSingleton();

        if (unenchantedItem) {
            player->RemoveItem(item, 1, RE::ITEM_REMOVE_REASON::kRemove, nullptr, nullptr);
            player->AddObjectToContainer(unenchantedItem, nullptr, 1, nullptr);
        } else if (templateItem) {
            auto xListOld = GetExtraHealthList(a_entry->extraLists);

            if (xListOld) {
                auto xListNew = ConstructExtraDataList(RE::MemoryManager::GetSingleton()->Allocate(0x20, 0, false));
                SetExtraHealth(xListNew, GetExtraHealth(xListOld));

                player->RemoveItem(item, 1, RE::ITEM_REMOVE_REASON::kRemove, xListOld, nullptr);
                player->AddObjectToContainer(templateItem, xListNew, 1, nullptr);
            } else {
                player->RemoveItem(item, 1, RE::ITEM_REMOVE_REASON::kRemove, nullptr, nullptr);
                player->AddObjectToContainer(templateItem, nullptr, 1, nullptr);
            }
        }

        UpdateUI();
    }
}

void System::UpdateUI()
{
    const auto queue = RE::UIMessageQueue::GetSingleton();
    const auto strings = RE::InterfaceStrings::GetSingleton();
    const auto tasks = SKSE::GetTaskInterface();
        
    tasks->AddUITask([queue, strings]() {
        queue->AddMessage(strings->craftingMenu, RE::UI_MESSAGE_TYPE::kHide, nullptr);
        queue->AddMessage(strings->craftingMenu, RE::UI_MESSAGE_TYPE::kShow, nullptr);
    });
}

auto System::ConstructExtraDataList(void* a_this) -> RE::ExtraDataList*
{
    using func_t = decltype(&ConstructExtraDataList);
    REL::Relocation<func_t> func{ RELOCATION_ID(11437, 11583) };
    return func(a_this);
}

auto System::GetExtraHealth(RE::ExtraDataList* a_extra) -> float
{
    using func_t = decltype(&GetExtraHealth);
    REL::Relocation<func_t> func{ RELOCATION_ID(11557, 11703) };
    return func(a_extra);
}

void System::SetExtraHealth(RE::ExtraDataList* a_extra, float a_health)
{
    using func_t = decltype(&SetExtraHealth);
    REL::Relocation<func_t> func{ RELOCATION_ID(11470, 11616) };
    return func(a_extra, a_health);
}
