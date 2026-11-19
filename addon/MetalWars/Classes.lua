local _, MW = ...

-- A short WSG toolkit. The client's spellbook decides what is actually learned.
-- Rank IDs are ordered highest first; never assume Classic cooldown durations.
MW.Classes = {
    WARRIOR = {
        hint = "Peel with Hamstring. Keep a shield handy for Shield Bash / Shield Block.",
        spells = {
            { ids = { 100 }, label = "Charge", note = "Check stance and range on your action bar." },
            { ids = { 1715 }, label = "Hamstring", note = "A peel / pursuit reminder; no cooldown does not mean usable." },
            { ids = { 72 }, label = "Shield Bash", note = "Requires a shield and the appropriate stance." },
            { ids = { 676 }, label = "Disarm", note = "Check your stance before using it." },
            { ids = { 2687 }, label = "Bloodrage", note = "Resource tool; read the live spell tooltip." },
            { ids = { 2565 }, label = "Shield Block", note = "Requires a shield and the appropriate stance." },
        },
    },
    PALADIN = {
        hint = "Support the carrier with Freedom and Purify. Check immunity before carrying.",
        spells = {
            { ids = { 1044 }, label = "Freedom", note = "Keep an eye on the flag carrier." },
            { ids = { 853 }, label = "Justice", note = "A control tool for peeling or stopping a runner." },
            { ids = { 1152 }, label = "Purify", note = "Read the live tooltip for dispel types; this is not Cleanse." },
            { ids = { 633 }, label = "Lay on Hands", note = "The live client supplies its cooldown, not Classic values." },
            { ids = { 1022 }, label = "Protection", caution = true,
                note = "Flag-carrier caution: immunity can conflict with carrying. Check the current client behavior." },
            { ids = { 5573, 498 }, label = "Divine Prot.", caution = true,
                note = "Flag-carrier caution: immunity can conflict with carrying. Check the current client behavior." },
        },
    },
}

function MW:KnownSpell(entry)
    local known = C_SpellBook and C_SpellBook.IsSpellKnown
    if not known then return nil end
    for _, id in ipairs(entry.ids) do
        if self:Read(known, id) == true then return id end
    end
end
