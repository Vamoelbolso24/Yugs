-- ============================================================================
-- YUGS CUSTOM UTILITY
-- Shared helpers for custom cards. The game loads this file at the start of
-- every duel, before any card script, so every custom card can use what's here.
-- ============================================================================

-- Subtypes (archetype numbers). Must match content/custom/subtypes.json.
-- Use in scripts like: c:IsSetCard(SET_POKEMON)
SET_POKEMON = 0xf01
SET_PIKACHU = 0xf02
SET_NIDO    = 0xf03   -- every Nidoran / Nidorina / Nidoqueen / Nidorino / Nidoking
SET_NIDORAN = 0xf04   -- Nidoran Female and Nidoran Male
SET_WEATHER = 0xf05   -- "Weather Condition" cards (Sandstorm, Sunny Day)
SET_TEAM_ROCKET = 0xf06   -- "Team Rocket" cards
SET_GYM_LEADER  = 0xf07   -- "Gym Leader" cards
SET_POLI        = 0xf08   -- "Poli" cards
SET_SLOW        = 0xf09   -- "Slow" cards (Slowpoke, Slowbro)
SET_MENTIONS_POKEMON = 0xf0a   -- given automatically to Spells/Traps whose text says "Pokemon" (not in subtypes.json)
SET_MAROWAK     = 0xf0b   -- "Marowak" cards
SET_EXEGG       = 0xf0c   -- "Exegg" cards (Exeggcute, Exeggutor)
SET_HITMON      = 0xf0d   -- "Hitmon" cards (Hitmonlee, Hitmonchan)
SET_POKEMON_TRAINER = 0xf0e   -- "Pokemon Trainer" cards (Bug Catcher, Fisherman)
SET_FOSSIL_PKMN = 0xf0f   -- "Fossil Pkmn" monsters (Omanyte, Kabuto, Aerodactyl...)
SET_FOSSIL      = 0xf10   -- "Fossil" cards (every Fossil Pkmn, plus Fossil Maniac / Restoration Center)
SET_POKEMON_MASTER = 0xf11   -- "Pokemon Master" cards (Lance)

-- Card IDs that several scripts check for
CARD_SANDSTORM = 1900000042   -- Weather Condition - Sandstorm
CARD_SUNNY_DAY = 1900000065   -- Weather Condition - Sunny Day
CARD_THUNDER_STONE = 1900000037
CARD_FIRE_STONE    = 1900000054
CARD_RAIN_DANCE    = 1900000102   -- Weather Condition - Rain Dance
CARD_UMI           = 22702055     -- the real "Umi" (Rain Dance is also treated as it)
CARD_TOXIC_SPIKES  = 1900000124
CARD_WATER_STONE   = 1900000101
CARD_U_TURN        = 1900000021
CARD_EEVEE         = 1900000206
CARD_DITTO         = 1900000203
CARD_SURF          = 1900000204
CARD_NO_WEATHER    = 1900099001   -- "No Weather Condition" (the name Psyduck/Golduck give Weather cards)

-- Custom counters. Must match content/custom/counters.json (that file gives them their names).
-- The 0x1000 part means "can be placed on any card" (no permit needed).
COUNTER_HARDEN = 0x1f01
COUNTER_POISON = 0x1f02
COUNTER_BURN   = 0x1f03
COUNTER_SDANCE = 0x1f04   -- Swords Dance
COUNTER_C      = 0x1f05   -- C-Counter (Slowpoke, Slowbro, Calm Mind)
COUNTER_CURSE  = 0x1f06   -- Curse Counter (Gastly)

Pokemon = {}

-- A Level <= maxLevel Insect Pokemon in hand (used by Butterfree, Beedrill, U-Turn).
function Pokemon.InsectFilter(c,e,tp,maxLevel,exceptCode)
	return c:IsSetCard(SET_POKEMON) and c:IsRace(RACE_INSECT) and c:IsLevelBelow(maxLevel)
		and (not exceptCode or not c:IsCode(exceptCode)) and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end

-- ----------------------------------------------------------------------------
-- HARDEN COUNTERS (Metapod, Kakuna)
-- "During your Standby Phase: You can place a Harden Counter on this card.
--  (Pokemon monsters with a Harden Counter gain 300 DEF for each counter on them.)"
-- HOW TO USE: Pokemon.AddHarden(c, 0)   -- 0 = which Prompt shows for it (0 = Prompt 1)
-- ----------------------------------------------------------------------------
function Pokemon.AddHarden(c,promptIndex)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(c:GetOriginalCode(),promptIndex))
	e1:SetCategory(CATEGORY_COUNTER)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return e:GetHandler():IsCanAddCounter(COUNTER_HARDEN,1) end
		Duel.SetOperationInfo(0,CATEGORY_COUNTER,e:GetHandler(),1,COUNTER_HARDEN,1)
	end)
	e1:SetOperation(function(e)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) and c:IsFaceup() then c:AddCounter(COUNTER_HARDEN,1) end
	end)
	c:RegisterEffect(e1)
	-- +300 DEF per Harden Counter
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCode(EFFECT_UPDATE_DEFENSE)
	e2:SetValue(function(e,c) return c:GetCounter(COUNTER_HARDEN)*300 end)
	c:RegisterEffect(e2)
end

-- ----------------------------------------------------------------------------
-- POISON COUNTERS (Ekans)
-- "(During each Standby Phase, each player takes 300 damage for each Poison
--  Counter on cards they control.)"
-- HOW TO USE: Pokemon.EnablePoisonRule() inside s.initial_effect of any card that
-- places Poison Counters. The rule is switched on once for the whole duel.
-- ----------------------------------------------------------------------------
function Pokemon.EnablePoisonRule()
	if Pokemon.poisonRuleOn then return end
	Pokemon.poisonRuleOn=true
	local ge=Effect.GlobalEffect()
	ge:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	ge:SetCode(EVENT_PHASE+PHASE_STANDBY)
	ge:SetCountLimit(1)
	ge:SetOperation(function(e,tp)
		for p=0,1 do
			local n=Duel.GetCounter(p,LOCATION_ONFIELD,0,COUNTER_POISON)
			if n>0 then Duel.Damage(p,n*300,REASON_EFFECT) end
		end
	end)
	Duel.RegisterEffect(ge,0)
end

-- ----------------------------------------------------------------------------
-- EVOLUTION SUMMON
-- "You can Special Summon this card from your hand by Tributing 1 <previous form>
--  from your hand or field, or by banishing 1 <previous form> from your GY."
--
-- HOW TO USE: inside a card's s.initial_effect(c), add ONE line:
--     Pokemon.AddEvolutionSummon(c, 1900000002)   -- 1900000002 = the card it evolves from
--
-- Hard once per turn: "You can only Special Summon <this card> once per turn this way."
-- (per card name, shared by all copies). For a Pokemon WITHOUT that limit, add true at the end:
--     Pokemon.AddEvolutionSummon(c, 1900000002, true)
--
-- It works like Cyber Dragon: a built-in way to Special Summon, so it does not
-- start a chain and can't be responded to (Solemn-style cards can still negate it).
--
-- To do something "if Summoned this way", check Pokemon.IsEvolutionSummoned(c)
-- in the condition of an EVENT_SPSUMMON_SUCCESS trigger (see Charmeleon, c1900000006.lua).
-- ----------------------------------------------------------------------------

-- A marker stored on the card's summon type, so we can tell it was Evolution Summoned.
Pokemon.EVOLUTION = 0x2e1

function Pokemon.IsEvolutionSummoned(c)
	return c:GetSummonType()==SUMMON_TYPE_SPECIAL+Pokemon.EVOLUTION
end

-- Which cards can be used: the previous form, face-up on your field or in your hand (to Tribute),
-- or in your GY (to banish). There must be a free Monster Zone after it leaves.
function Pokemon.EvolutionMaterial(mc,tp,fromCode)
	if not mc:IsCode(fromCode) then return false end
	if mc:IsLocation(LOCATION_GRAVE) then
		return mc:IsAbleToRemoveAsCost() and Duel.GetLocationCount(tp,LOCATION_MZONE)>0
	end
	if mc:IsLocation(LOCATION_MZONE) and not mc:IsFaceup() then return false end
	return mc:IsReleasable() and Duel.GetMZoneCount(tp,mc)>0
end

function Pokemon.AddEvolutionSummon(c,fromCode,noLimit)
	local e=Effect.CreateEffect(c)
	e:SetType(EFFECT_TYPE_FIELD)
	e:SetCode(EFFECT_SPSUMMON_PROC)               -- a built-in Special Summon (like Cyber Dragon)
	e:SetProperty(EFFECT_FLAG_UNCOPYABLE)
	e:SetRange(LOCATION_HAND)                     -- summoned from the hand
	e:SetValue(Pokemon.EVOLUTION)                 -- marks it as an Evolution Summon
	if not noLimit then
		-- "You can only Special Summon <name> once per turn this way" (OATH = counts even if negated).
		-- {code,10} gives this limit its own counter, separate from the card's other once-per-turn effects.
		e:SetCountLimit(1,{c:GetOriginalCode(),10},EFFECT_COUNT_CODE_OATH)
	end
	-- Condition: is there a previous form we could use right now?
	e:SetCondition(function(e,c)
		if c==nil then return true end
		local tp=c:GetControler()
		return Duel.IsExistingMatchingCard(Pokemon.EvolutionMaterial,tp,LOCATION_HAND|LOCATION_MZONE|LOCATION_GRAVE,0,1,c,tp,fromCode)
	end)
	-- Target: the player picks which previous form to use.
	e:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,c)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RELEASE)
		local g=Duel.SelectMatchingCard(tp,Pokemon.EvolutionMaterial,tp,LOCATION_HAND|LOCATION_MZONE|LOCATION_GRAVE,0,1,1,c,tp,fromCode)
		if #g==0 then return false end
		g:KeepAlive()
		e:SetLabelObject(g)
		return true
	end)
	-- Operation: Tribute it (hand/field) or banish it (GY).
	e:SetOperation(function(e,tp,eg,ep,ev,re,r,rp,c)
		local g=e:GetLabelObject()
		if not g then return end
		if g:GetFirst():IsLocation(LOCATION_GRAVE) then
			Duel.Remove(g,POS_FACEUP,REASON_COST)
		else
			Duel.Release(g,REASON_COST)
		end
		g:DeleteGroup()
	end)
	c:RegisterEffect(e)
	return e
end

-- ----------------------------------------------------------------------------
-- RETURN AND SWITCH (Butterfree, Beedrill, U-Turn)
-- "Return <card> to the hand, and if you do, Special Summon 1 Level <maxLevel> or lower
--  Insect Pokemon from your hand (except <exceptCode>)."
-- Call it from an effect's operation: Pokemon.ReturnAndSwitch(e,tp,c,5,id)
-- ----------------------------------------------------------------------------
function Pokemon.ReturnAndSwitch(e,tp,c,maxLevel,exceptCode)
	if not c then return end
	-- The card itself must still be the same card on the field; another card just has to be on the field.
	local still = (c==e:GetHandler()) and c:IsRelateToEffect(e) or c:IsOnField()
	if not (still and c:IsAbleToHand()) then return end
	if Duel.SendtoHand(c,nil,REASON_EFFECT)==0 or not c:IsLocation(LOCATION_HAND) then return end
	if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
	local g=Duel.GetMatchingGroup(Pokemon.InsectFilter,tp,LOCATION_HAND,0,nil,e,tp,maxLevel,exceptCode)
	if #g==0 then return end
	Duel.BreakEffect()
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local sg=g:Select(tp,1,1,nil)
	Duel.SpecialSummon(sg,0,tp,tp,false,false,POS_FACEUP)
end

-- ----------------------------------------------------------------------------
-- SEARCH WHEN SUMMONED (Nidoran Female, Nidorina, Nidorino)
-- "If this card is Summoned: You can add 1 <filter> monster from your Deck to your hand.
--  You can only use this effect of <this card> once per turn."
-- HOW TO USE: Pokemon.AddSummonSearch(c, 0, function(tc) return tc:IsCode(1900000048) end)
--   0 = which Prompt shows for it (0 = Prompt 1). The function says which cards can be added.
-- "Summoned" = Normal, Flip or Special Summoned, so the same trigger is registered 3 times.
-- ----------------------------------------------------------------------------
function Pokemon.AddSummonSearch(c,promptIndex,filter)
	local function thfilter(tc) return tc:IsMonster() and filter(tc) and tc:IsAbleToHand() end
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(c:GetOriginalCode(),promptIndex))
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetCountLimit(1,c:GetOriginalCode())          -- hard once per turn (all copies share it)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(thfilter,tp,LOCATION_DECK,0,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectMatchingCard(tp,thfilter,tp,LOCATION_DECK,0,1,1,nil)
		if #g>0 then
			Duel.SendtoHand(g,nil,REASON_EFFECT)
			Duel.ConfirmCards(1-tp,g)                -- show the opponent what you added
		end
	end)
	c:RegisterEffect(e1)
	local e2=e1:Clone() e2:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e2)
	local e3=e1:Clone() e3:SetCode(EVENT_FLIP_SUMMON_SUCCESS) c:RegisterEffect(e3)
end

-- ----------------------------------------------------------------------------
-- NIDO BOOST AND IMMUNITY (Nidorina, Nidorino, Nidoqueen, Nidoking)
-- Pokemon.AddNidoBoost(c)            "Nido" monsters you control, except <this card's name>, gain 300 ATK/DEF.
-- Pokemon.AddNidoImmunity(c,TYPE_TRAP)  ...are unaffected by your opponent's Trap effects (TYPE_SPELL for Spells).
-- ----------------------------------------------------------------------------
local function otherNido(e,tc) return tc:IsFaceup() and tc:IsSetCard(SET_NIDO) and not tc:IsCode(e:GetHandler():GetCode()) end
function Pokemon.AddNidoBoost(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(LOCATION_MZONE,0)
	e1:SetTarget(otherNido)
	e1:SetValue(300)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_UPDATE_DEFENSE)
	c:RegisterEffect(e2)
end
function Pokemon.AddNidoImmunity(c,cardType)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_IMMUNE_EFFECT)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(LOCATION_MZONE,0)
	e1:SetTarget(otherNido)
	-- te = the effect trying to affect them: ignore it if it's an opponent's Spell/Trap effect
	e1:SetValue(function(e,te) return te:IsActiveType(cardType) and te:GetOwnerPlayer()~=e:GetHandlerPlayer() end)
	c:RegisterEffect(e1)
end

-- ----------------------------------------------------------------------------
-- BURN COUNTERS (Vulpix, Ninetales)
-- "Once per turn, you can place a Burn Counter on an opponent's monster.
--  (A monster with a Burn Counter loses 300 ATK for each Burn Counter on it.)"
-- HOW TO USE: Pokemon.AddBurnCounter(c, 0)   -- 0 = which Prompt shows for it
-- ----------------------------------------------------------------------------
function Pokemon.EnableBurnRule()
	if Pokemon.burnRuleOn then return end         -- only switch the rule on once per duel
	Pokemon.burnRuleOn=true
	local ge=Effect.GlobalEffect()
	ge:SetType(EFFECT_TYPE_FIELD)
	ge:SetCode(EFFECT_UPDATE_ATTACK)
	ge:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)   -- every monster on the field
	ge:SetTarget(function(e,tc) return tc:GetCounter(COUNTER_BURN)>0 end)
	ge:SetValue(function(e,tc) return tc:GetCounter(COUNTER_BURN)*-300 end)
	Duel.RegisterEffect(ge,0)
end
function Pokemon.BurnFilter(tc) return tc:IsFaceup() and tc:IsCanAddCounter(COUNTER_BURN,1) end
function Pokemon.AddBurnCounter(c,promptIndex)
	Pokemon.EnableBurnRule()
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(c:GetOriginalCode(),promptIndex))
	e1:SetCategory(CATEGORY_COUNTER)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)                            -- soft once per turn (each copy)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Pokemon.BurnFilter,tp,0,LOCATION_MZONE,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_COUNTER,nil,1,0,COUNTER_BURN)
	end)
	e1:SetOperation(function(e,tp)
		-- not a target: the monster is picked when the effect resolves
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_COUNTER)
		local tc=Duel.SelectMatchingCard(tp,Pokemon.BurnFilter,tp,0,LOCATION_MZONE,1,1,nil):GetFirst()
		if tc then
			tc:AddCounter(COUNTER_BURN,1)              -- <<< HERE the Burn Counter is placed
		end
	end)
	c:RegisterEffect(e1)
end

-- ----------------------------------------------------------------------------
-- EXCAVATE AND APPLY (Clefairy, Clefable)
-- "Excavate the top card of your Deck, and if it is a <kind> card, immediately apply its
--  effects and then shuffle it into the Deck. Otherwise, place it on the bottom of your Deck."
-- Call it from an effect's operation:
--     Pokemon.ExcavateAndApply(e,tp,eg,ep,ev,re,r,rp, Card.IsNormalSpell)
-- The card is moved to the bottom BEFORE its effect is applied, so a card like Pot of Greed
-- doesn't draw itself; it is shuffled in afterwards. Costs are not paid (it's applied, not activated).
-- If it's the right kind but its effect can't be used right now, nothing happens and it's shuffled in.
-- timingOk (optional): extra check on the card's activation effect (Clefable's Trap timing).
-- ----------------------------------------------------------------------------
function Pokemon.ApplyEffect(e,tp,te,eg,ep,ev,re,r,rp)
	local con,tg,op=te:GetCondition(),te:GetTarget(),te:GetOperation()
	if con and not con(e,tp,eg,ep,ev,re,r,rp) then return false end
	if tg and not tg(e,tp,eg,ep,ev,re,r,rp,0) then return false end   -- could it do anything now?
	if tg then tg(e,tp,eg,ep,ev,re,r,rp,1) end                          -- choose its targets
	if op then op(e,tp,eg,ep,ev,re,r,rp) end                            -- do what it does
	return true
end
-- eventArgs (optional): a function returning {eg,ep,ev,re,r,rp} of the moment the Trap waits for.
function Pokemon.ExcavateAndApply(e,tp,eg,ep,ev,re,r,rp,kind,timingOk,eventArgs)
	if Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)==0 then return end
	Duel.ConfirmDecktop(tp,1)                      -- both players see the top card
	local tc=Duel.GetDecktopGroup(tp,1):GetFirst()
	local te=tc:GetActivateEffect()
	Duel.MoveToDeckBottom(tc)
	if kind(tc) then
		if te and (not timingOk or timingOk(te)) then
			local args=eventArgs and eventArgs()
			if args then eg,ep,ev,re,r,rp=table.unpack(args,1,6) end
			Pokemon.ApplyEffect(e,tp,te,eg,ep,ev,re,r,rp)
		end
		Duel.ShuffleDeck(tp)                       -- right kind: shuffle it in (even if it couldn't be applied)
	end                                            -- wrong kind: it stays on the bottom
end

-- ----------------------------------------------------------------------------
-- WEATHER (Sandstorm, Sunny Day)
-- Pokemon.IsOnField(code): is a face-up card with this ID on either player's field?
--     if Pokemon.IsOnField(CARD_SUNNY_DAY) then ... end
-- Pokemon.AddWeatherActivation(c): "Destroy this card during your 5th End Phase after its activation."
--     Registers the card's activation and the countdown. The End Phase of the turn you activate it is the 1st.
-- ----------------------------------------------------------------------------
function Pokemon.IsOnField(code)
	return Duel.IsExistingMatchingCard(aux.FaceupFilter(Card.IsCode,code),0,LOCATION_ONFIELD,LOCATION_ONFIELD,1,nil)
end
function Pokemon.AddWeatherActivation(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		local c=e:GetHandler()
		c:SetTurnCounter(0)                  -- start counting your End Phases (like Swords of Concealing Light)
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
		e2:SetCode(EVENT_PHASE+PHASE_END)
		e2:SetRange(LOCATION_SZONE)
		e2:SetCountLimit(1)
		e2:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) end)   -- only YOUR End Phases count
		e2:SetOperation(function(e)
			local c=e:GetHandler()
			local ct=c:GetTurnCounter()+1
			c:SetTurnCounter(ct)
			if ct>=5 then Duel.Destroy(c,REASON_RULE) end
		end)
		e2:SetReset(RESET_EVENT|RESETS_STANDARD)
		c:RegisterEffect(e2)
	end)
	c:RegisterEffect(e1)
	return e1
end

-- ----------------------------------------------------------------------------
-- STONES (Fire Stone, Leaf Stone)
-- "Tribute 1 <kind of> Pokemon monster you control to Special Summon from your Deck 1 monster that
--  mentions the Tributed monster's name. For the rest of the turn, you cannot Summon monsters with
--  the same name as the monster Special Summoned by this effect."
-- HOW TO USE (in a Normal Spell's s.initial_effect):
--     Pokemon.AddStoneEffect(c, function(tc) return tc:IsAttribute(ATTRIBUTE_FIRE) end)
-- (Thunder Stone and Moon Stone are the older kind: "a monster that mentions this Stone", Deck or GY.)
-- ----------------------------------------------------------------------------
function Pokemon.AddStoneEffect(c,kind)
	local function spfilter(sc,e,tp,code)
		return sc:IsMonster() and sc:ListsCode(code) and sc:IsCanBeSpecialSummoned(e,0,tp,false,false)
	end
	-- A face-up <kind> Pokemon you control that has something in the Deck to evolve into
	local function cfilter(tc,e,tp)
		return tc:IsFaceup() and tc:IsSetCard(SET_POKEMON) and kind(tc) and tc:IsReleasable()
			and Duel.GetMZoneCount(tp,tc)>0
			and Duel.IsExistingMatchingCard(spfilter,tp,LOCATION_DECK,0,1,nil,e,tp,tc:GetCode())
	end
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(cfilter,tp,LOCATION_MZONE,0,1,nil,e,tp) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RELEASE)
		local tc=Duel.SelectMatchingCard(tp,cfilter,tp,LOCATION_MZONE,0,1,1,nil,e,tp):GetFirst()
		e:SetLabel(tc:GetCode())               -- remember the Tributed monster's name
		Duel.Release(tc,REASON_COST)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end         -- checked in the cost
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_DECK)
	end)
	e1:SetOperation(function(e,tp)
		if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
		local tc=Duel.SelectMatchingCard(tp,spfilter,tp,LOCATION_DECK,0,1,1,nil,e,tp,e:GetLabel()):GetFirst()
		if not tc or Duel.SpecialSummon(tc,0,tp,tp,false,false,POS_FACEUP)==0 then return end
		-- No more Summons (Normal, Special, Flip, Set) of that name this turn
		local code=tc:GetCode()
		for _,eff in ipairs({EFFECT_CANNOT_SUMMON,EFFECT_CANNOT_SPECIAL_SUMMON,EFFECT_CANNOT_MSET,EFFECT_CANNOT_FLIP_SUMMON}) do
			local e2=Effect.CreateEffect(e:GetHandler())
			e2:SetType(EFFECT_TYPE_FIELD)
			e2:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
			e2:SetCode(eff)
			e2:SetTargetRange(1,0)
			e2:SetTarget(function(e,c) return c:IsCode(code) end)
			e2:SetReset(RESET_PHASE|PHASE_END)
			Duel.RegisterEffect(e2,tp)
		end
	end)
	c:RegisterEffect(e1)
	return e1
end

-- ----------------------------------------------------------------------------
-- NO TRIBUTES (Diglett, Dugtrio)
-- "Cards your opponent controls or in their hand cannot be Tributed."
-- HOW TO USE: Pokemon.AddNoTributeLock(c)
-- ----------------------------------------------------------------------------
function Pokemon.AddNoTributeLock(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_UNRELEASABLE_SUM)        -- can't be Tributed for a Tribute Summon
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(0,LOCATION_ONFIELD|LOCATION_HAND)   -- your opponent's field and hand
	e1:SetValue(1)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_UNRELEASABLE_NONSUM)     -- ...or for anything else (costs, Evolution Summons...)
	c:RegisterEffect(e2)
end

-- ----------------------------------------------------------------------------
-- GYM LEADERS
-- Pokemon.AddGymLeader(c, condition, target, operation)
--   "You can only control 1 "Gym Leader" card." + the card's activation.
--   condition/target/operation are optional: what happens "When this card is activated".
-- Pokemon.ActivationSearch(tp, filter, prompt): "When this card is activated: You can add 1 <filter> card
--   from your Deck to your hand." Call it from the activation's operation.
-- ----------------------------------------------------------------------------
function Pokemon.AddGymLeader(c,condition,target,operation)
	-- Only 1 Gym Leader on YOUR field (the opponent can have their own)
	c:SetUniqueOnField(1,0,function(tc) return tc:IsSetCard(SET_GYM_LEADER) end)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	if condition then e1:SetCondition(condition) end
	if target then e1:SetTarget(target) end
	if operation then e1:SetOperation(operation) end
	c:RegisterEffect(e1)
	return e1
end
function Pokemon.ActivationSearch(e,tp,filter,prompt)
	if not e:GetHandler():IsRelateToEffect(e) then return end
	local function f(tc) return filter(tc) and tc:IsAbleToHand() end
	if not Duel.IsExistingMatchingCard(f,tp,LOCATION_DECK,0,1,nil) then return end
	if not Duel.SelectYesNo(tp,prompt) then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
	local g=Duel.SelectMatchingCard(tp,f,tp,LOCATION_DECK,0,1,1,nil)
	if #g>0 then
		Duel.SendtoHand(g,nil,REASON_EFFECT)
		Duel.ConfirmCards(1-tp,g)
	end
end

-- ----------------------------------------------------------------------------
-- NEGATE A TARGETING ACTIVATION (Erika, Koga)
-- Pokemon.TargetsMine(tp, ev, filter): does Chain Link ev target a card I control that matches filter?
-- ----------------------------------------------------------------------------
function Pokemon.TargetsMine(tp,ev,filter)
	local te,g=Duel.GetChainInfo(ev,CHAININFO_TRIGGERING_EFFECT,CHAININFO_TARGET_CARDS)
	if not (te and te:IsHasProperty(EFFECT_FLAG_CARD_TARGET)) or not g then return false end
	return g:IsExists(function(tc) return tc:IsControler(tp) and tc:IsLocation(LOCATION_MZONE) and tc:IsFaceup() and filter(tc) end,1,nil)
end

-- ----------------------------------------------------------------------------
-- "NOMI" SUMMON (Alakazam, Machamp)
-- "Cannot be Normal Summoned/Set. Must first be Special Summoned (from your hand) by Tributing 1 <fromCode>
--  you control."  HOW TO USE: Pokemon.AddNomiSummon(c, 1900000105)
-- "If Summoned this way" = Pokemon.IsNomiSummoned(c).
-- ----------------------------------------------------------------------------
Pokemon.NOMI = 0x2e2
function Pokemon.IsNomiSummoned(c) return c:GetSummonType()==SUMMON_TYPE_SPECIAL+Pokemon.NOMI end
function Pokemon.AddNomiSummon(c,fromCode)
	c:EnableReviveLimit()                         -- "must first be Special Summoned" (Monster Reborn needs that first)
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_SINGLE)
	e0:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e0:SetCode(EFFECT_SPSUMMON_CONDITION)
	e0:SetValue(aux.FALSE)                        -- no other way to Special Summon it from the hand
	c:RegisterEffect(e0)
	local function mat(mc,tp) return mc:IsFaceup() and mc:IsCode(fromCode) and mc:IsReleasable() and Duel.GetMZoneCount(tp,mc)>0 end
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SPSUMMON_PROC)
	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_CANNOT_DISABLE)
	e1:SetRange(LOCATION_HAND)
	e1:SetValue(Pokemon.NOMI)
	e1:SetCondition(function(e,c)
		if c==nil then return true end
		return Duel.IsExistingMatchingCard(mat,c:GetControler(),LOCATION_MZONE,0,1,nil,c:GetControler())
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,c)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RELEASE)
		local g=Duel.SelectMatchingCard(tp,mat,tp,LOCATION_MZONE,0,1,1,nil,tp)
		if #g==0 then return false end
		g:KeepAlive()
		e:SetLabelObject(g)
		return true
	end)
	e1:SetOperation(function(e,tp,eg,ep,ev,re,r,rp,c)
		local g=e:GetLabelObject()
		Duel.Release(g,REASON_COST)
		g:DeleteGroup()
	end)
	c:RegisterEffect(e1)
end
-- "Control of this card cannot change."
function Pokemon.AddNoControlChange(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_CANNOT_CHANGE_CONTROL)
	c:RegisterEffect(e1)
end

-- ----------------------------------------------------------------------------
-- GROWTH (Bellsprout, Weepingbell)
-- "During your Standby Phase: You can make this card gain 200 ATK, or 400 ATK instead if "Sunny Day" is on
--  the field. This card cannot declare an attack the turn you activate this effect."
-- HOW TO USE: Pokemon.AddGrowth(c, 0)   -- 0 = Prompt 1
-- ----------------------------------------------------------------------------
function Pokemon.AddGrowth(c,promptIndex)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(c:GetOriginalCode(),promptIndex))
	e1:SetCategory(CATEGORY_ATKCHANGE)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) end)
	e1:SetOperation(function(e)
		local c=e:GetHandler()
		if not (c:IsRelateToEffect(e) and c:IsFaceup()) then return end
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_UPDATE_ATTACK)
		e1:SetValue(Pokemon.IsOnField(CARD_SUNNY_DAY) and 400 or 200)
		e1:SetReset(RESET_EVENT|RESETS_STANDARD)     -- stays (the ATK gain is permanent)
		c:RegisterEffect(e1)
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_SINGLE)
		e2:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
		e2:SetReset(RESETS_STANDARD_PHASE_END)       -- only this turn
		c:RegisterEffect(e2)
	end)
	c:RegisterEffect(e1)
end

-- ----------------------------------------------------------------------------
-- PROTECTION FROM AN ATTRIBUTE (Poliwhirl, Poliwrath: WATER. Graveler, Golem: LIGHT)
-- "Cannot be destroyed by battle with, or targeted by the effects of, <attribute> monsters."
-- HOW TO USE: Pokemon.AddAttributeProtection(c, ATTRIBUTE_LIGHT)
-- ----------------------------------------------------------------------------
function Pokemon.AddAttributeProtection(c,attr)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_INDESTRUCTABLE_BATTLE)
	e1:SetValue(function(e,bc) return bc:IsAttribute(attr) end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	e2:SetValue(function(e,re) return re:IsMonsterEffect() and re:GetHandler():IsAttribute(attr) end)
	c:RegisterEffect(e2)
end
function Pokemon.AddWaterProtection(c) Pokemon.AddAttributeProtection(c,ATTRIBUTE_WATER) end

-- ----------------------------------------------------------------------------
-- PSYDUCK / GOLDUCK
-- Pokemon.AddCloudNine(c): "Negate the effects of all "Weather Condition" cards, also those cards' names
--   become "No Weather Condition"." (They are still Weather Condition cards, so they stay negated.)
-- Pokemon.AddDestroyNegate(c, promptIndex): "Once per turn, when your opponent activates a card or effect
--   that would destroy a monster(s) they control: You can negate the activation, and if you do, destroy it."
-- ----------------------------------------------------------------------------
function Pokemon.AddCloudNine(c)
	-- IsOriginalSetCard (the archetype printed on the card), not IsSetCard: the name change below would
	-- otherwise make the game re-check this filter while it's working out the card's name, and give up.
	local function weather(e,tc) return tc:IsOriginalSetCard(SET_WEATHER) end
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_DISABLE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(LOCATION_ONFIELD,LOCATION_ONFIELD)
	e1:SetTarget(weather)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_CHANGE_CODE)
	e2:SetValue(CARD_NO_WEATHER)
	c:RegisterEffect(e2)
end
function Pokemon.AddDestroyNegate(c,promptIndex)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(c:GetOriginalCode(),promptIndex))
	e1:SetCategory(CATEGORY_NEGATE+CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_QUICK_O)
	e1:SetCode(EVENT_CHAINING)
	e1:SetRange(LOCATION_MZONE)
	e1:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		if rp~=1-tp or e:GetHandler():IsStatus(STATUS_BATTLE_DESTROYED) or not Duel.IsChainNegatable(ev) then return false end
		-- what that card says it will destroy (its "operation info")
		local ex,tg,ct,p,loc=Duel.GetOperationInfo(ev,CATEGORY_DESTROY)
		if not ex then return false end
		if tg and tg:IsExists(function(tc) return tc:IsControler(1-tp) and tc:IsLocation(LOCATION_MZONE) end,1,nil) then return true end
		-- no exact cards listed (like Dark Hole): check the places it destroys from
		return not tg and loc and (loc&LOCATION_MZONE)~=0 and (p==1-tp or p==PLAYER_ALL)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_NEGATE,eg,1,0,0)
		if re:GetHandler():IsDestructable() and re:GetHandler():IsRelateToEffect(re) then
			Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,1,0,0)
		end
	end)
	e1:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		if Duel.NegateActivation(ev) and re:GetHandler():IsRelateToEffect(re) then
			Duel.Destroy(eg,REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e1)
end

-- ----------------------------------------------------------------------------
-- C-COUNTERS (Slowpoke, Slowbro, Calm Mind)
-- Pokemon.EnableCRule(): "(Monsters with a C-Counter gain 300 ATK/DEF for each C-Counter on them.)"
-- Pokemon.AddCCounterStandby(c, prompt): "Once per turn, during your Standby Phase: You can place 1 C-Counter
--   on this card (max. 4). This card cannot declare an attack the turn you activate this effect."
-- ----------------------------------------------------------------------------
function Pokemon.EnableCRule()
	if Pokemon.cRuleOn then return end
	Pokemon.cRuleOn=true
	local ge=Effect.GlobalEffect()
	ge:SetType(EFFECT_TYPE_FIELD)
	ge:SetCode(EFFECT_UPDATE_ATTACK)
	ge:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	ge:SetTarget(function(e,tc) return tc:GetCounter(COUNTER_C)>0 end)
	ge:SetValue(function(e,tc) return tc:GetCounter(COUNTER_C)*300 end)
	Duel.RegisterEffect(ge,0)
	local ge2=ge:Clone()
	ge2:SetCode(EFFECT_UPDATE_DEFENSE)
	Duel.RegisterEffect(ge2,0)
end
function Pokemon.AddCCounterStandby(c,promptIndex)
	Pokemon.EnableCRule()
	c:SetCounterLimit(COUNTER_C,4)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(c:GetOriginalCode(),promptIndex))
	e1:SetCategory(CATEGORY_COUNTER)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return e:GetHandler():IsCanAddCounter(COUNTER_C,1) end
		Duel.SetOperationInfo(0,CATEGORY_COUNTER,e:GetHandler(),1,COUNTER_C,1)
	end)
	e1:SetOperation(function(e)
		local c=e:GetHandler()
		if not (c:IsRelateToEffect(e) and c:IsFaceup()) then return end
		c:AddCounter(COUNTER_C,1)
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_SINGLE)
		e2:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
		e2:SetReset(RESETS_STANDARD_PHASE_END)
		c:RegisterEffect(e2)
	end)
	c:RegisterEffect(e1)
end

-- ----------------------------------------------------------------------------
-- ROCK BODY (Graveler, Golem)
-- "Cannot be destroyed by battle or targeted by the effects of LIGHT monsters. This card can attack while in
--  face-up Defense Position. If this card battles with a WATER monster, at the start of the Damage Step:
--  Destroy this card."
-- ----------------------------------------------------------------------------
function Pokemon.AddRockBody(c)
	Pokemon.AddAttributeProtection(c,ATTRIBUTE_LIGHT)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	-- attacks from Defense Position. No SetValue = it still uses its ATK for damage calculation
	-- (SetValue(1) would make it use its DEF instead, like Superheavy Samurai).
	e1:SetCode(EFFECT_DEFENSE_ATTACK)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetCategory(CATEGORY_DESTROY)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_BATTLE_START)           -- start of the Damage Step
	e2:SetCondition(function(e)
		local bc=e:GetHandler():GetBattleTarget()
		return bc and bc:IsFaceup() and bc:IsAttribute(ATTRIBUTE_WATER)
	end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,e:GetHandler(),1,0,0)
	end)
	e2:SetOperation(function(e)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) then Duel.Destroy(c,REASON_EFFECT) end
	end)
	c:RegisterEffect(e2)
end

-- ----------------------------------------------------------------------------
-- SMALL SHARED EFFECTS
-- Pokemon.AddBattleSurvive(c): "The first time this card would be destroyed by battle each turn, it is not."
-- Pokemon.AddNoMachineSummon(c): "Your opponent cannot Special Summon Machine monsters."
-- Pokemon.MillTop(tp): send the top card of tp's Deck to the GY; returns that card (or nil).
-- ----------------------------------------------------------------------------
function Pokemon.AddBattleSurvive(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_INDESTRUCTABLE_COUNT)
	e1:SetCountLimit(1)
	e1:SetValue(function(e,re,r) return (r&REASON_BATTLE)~=0 end)
	c:RegisterEffect(e1)
end
function Pokemon.AddNoMachineSummon(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetCode(EFFECT_CANNOT_SPECIAL_SUMMON)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(0,1)
	e1:SetTarget(function(e,tc) return tc:IsRace(RACE_MACHINE) end)
	c:RegisterEffect(e1)
end
function Pokemon.MillTop(tp)
	if Duel.DiscardDeck(tp,1,REASON_EFFECT)==0 then return nil end
	return Duel.GetOperatedGroup():GetFirst()
end
function Pokemon.IsWaterPokemon(c) return c and c:IsMonster() and c:IsSetCard(SET_POKEMON) and c:IsAttribute(ATTRIBUTE_WATER) end

-- ----------------------------------------------------------------------------
-- "ITS EFFECT BECOMES ..." (Gastly, Curse)
-- Pokemon.CurseSpellTrap(source, tc, amount, hint): tc (a face-up Spell/Trap) loses its own effects and gets
-- "During your Standby Phase: Lose <amount> LP" (its controller loses it, in their own Standby Phases).
-- It stays like that while tc is face-up on the field, even if "source" leaves the field.
-- ----------------------------------------------------------------------------
-- hint (optional) = a Prompt shown on the card, like aux.Stringid(id,2).
function Pokemon.CurseSpellTrap(source,tc,amount,hint)
	for _,code in ipairs({EFFECT_DISABLE,EFFECT_DISABLE_EFFECT}) do
		local e1=Effect.CreateEffect(source)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(code)
		e1:SetReset(RESET_EVENT|RESETS_STANDARD)
		tc:RegisterEffect(e1)
	end
	-- the new effect belongs to tc itself, and can't be negated (tc is negated, its new effect isn't)
	local e2=Effect.CreateEffect(tc)
	if hint then e2:SetDescription(hint) end
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE|(hint and EFFECT_FLAG_CLIENT_HINT or 0))
	e2:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e2:SetRange(LOCATION_ONFIELD)
	e2:SetCountLimit(1)
	-- only in its controller's own Standby Phase
	e2:SetCondition(function(e) return Duel.IsTurnPlayer(e:GetHandler():GetControler()) end)
	e2:SetOperation(function(e)
		local p=e:GetHandler():GetControler()
		Duel.Hint(HINT_CARD,0,e:GetHandler():GetOriginalCode())
		Duel.SetLP(p,Duel.GetLP(p)-amount)
	end)
	e2:SetReset(RESET_EVENT|RESETS_STANDARD)
	tc:RegisterEffect(e2,true)
end

-- ----------------------------------------------------------------------------
-- CURSE COUNTERS (Gastly)
-- "If a monster has 2 or more Curse Counters, immediately send it to the GY, also it cannot activate its effects
--  in the GY and your opponent cannot target it with card effects (even if Gastly leaves the field)."
-- Pokemon.EnableCurseRule(): switched on once per duel by any card that places Curse Counters.
-- ----------------------------------------------------------------------------
function Pokemon.EnableCurseRule()
	if Pokemon.curseRuleOn then return end
	Pokemon.curseRuleOn=true
	local ge=Effect.GlobalEffect()
	ge:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	ge:SetCode(EVENT_ADJUST)                    -- checked whenever the game state settles
	ge:SetOperation(function(e)
		local g=Duel.GetMatchingGroup(function(tc) return tc:GetCounter(COUNTER_CURSE)>=2 end,0,LOCATION_MZONE,LOCATION_MZONE,nil)
		for tc in g:Iter() do
			local victim=tc:GetControler()    -- the player whose monster it was can't target it afterwards
			if Duel.SendtoGrave(tc,REASON_RULE)>0 and tc:IsLocation(LOCATION_GRAVE) then
				local stays=RESET_EVENT|RESET_TOFIELD|RESET_TOHAND|RESET_TODECK|RESET_REMOVE|RESET_TEMP_REMOVE
				local e1=Effect.GlobalEffect()
				e1:SetType(EFFECT_TYPE_SINGLE)
				e1:SetCode(EFFECT_CANNOT_TRIGGER)  -- can't activate its effects
				e1:SetReset(stays)
				tc:RegisterEffect(e1,true)
				local e2=e1:Clone()
				e2:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
				e2:SetValue(function(e,re) return re:GetOwnerPlayer()==victim end)
				tc:RegisterEffect(e2,true)
			end
		end
	end)
	Duel.RegisterEffect(ge,0)
end

-- ----------------------------------------------------------------------------
-- RANDOM DISCARD ON BATTLE DAMAGE (Haunter, Gengar)
-- "If this card inflicts battle damage to your opponent: Your opponent discards 1 random card."
-- HOW TO USE: Pokemon.AddRandomDiscardOnDamage(c)       -- no limit
--             Pokemon.AddRandomDiscardOnDamage(c, id)   -- "...once per turn" (hard, by card name)
-- ----------------------------------------------------------------------------
function Pokemon.AddRandomDiscardOnDamage(c,onceCode)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_HANDES)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_BATTLE_DAMAGE)
	if onceCode then e1:SetCountLimit(1,onceCode) end
	e1:SetCondition(function(e,tp,eg,ep) return ep==1-tp end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_HANDES,nil,0,1-tp,1)
	end)
	e1:SetOperation(function(e,tp)
		local g=Duel.GetFieldGroup(tp,0,LOCATION_HAND)
		if #g>0 then Duel.SendtoGrave(g:RandomSelect(tp,1),REASON_EFFECT|REASON_DISCARD) end
	end)
	c:RegisterEffect(e1)
end

-- "a Spell/Trap that states Pokemon in its text"
function Pokemon.MentionsPokemon(c) return c:IsSpellTrap() and c:IsSetCard(SET_MENTIONS_POKEMON) end

-- ----------------------------------------------------------------------------
-- "ALSO TREATED AS" A TYPE (Exeggutor, Marowak: "also treated as a Spellcaster monster")
-- ----------------------------------------------------------------------------
function Pokemon.AddExtraRace(c,race)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE|LOCATION_GRAVE)
	e1:SetCode(EFFECT_ADD_RACE)
	e1:SetValue(race)
	c:RegisterEffect(e1)
end

-- ----------------------------------------------------------------------------
-- POISON UP TO 2 (Muk, Weezing): "Once per turn: You can place 1 Poison Counter on up to 2 monsters on the field."
-- ----------------------------------------------------------------------------
function Pokemon.AddPoisonTwo(c,promptIndex)
	Pokemon.EnablePoisonRule()
	local function f(tc) return tc:IsFaceup() and tc:IsCanAddCounter(COUNTER_POISON,1) end
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(c:GetOriginalCode(),promptIndex))
	e1:SetCategory(CATEGORY_COUNTER)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(f,tp,LOCATION_MZONE,LOCATION_MZONE,1,nil) end
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_COUNTER)
		local g=Duel.SelectMatchingCard(tp,f,tp,LOCATION_MZONE,LOCATION_MZONE,1,2,nil)
		for tc in g:Iter() do tc:AddCounter(COUNTER_POISON,1) end
	end)
	c:RegisterEffect(e1)
end

-- ----------------------------------------------------------------------------
-- COIN POISON (Grimer, Koffing): "Once per turn: You can target 1 monster your opponent controls; toss a coin and
-- call it, and if you call it right, place 1 Poison Counter on it."
-- ----------------------------------------------------------------------------
function Pokemon.AddCoinPoison(c,promptIndex)
	Pokemon.EnablePoisonRule()
	local function f(tc) return tc:IsFaceup() and tc:IsCanAddCounter(COUNTER_POISON,1) end
	local e1=Effect.CreateEffect(c)
	if promptIndex then e1:SetDescription(aux.Stringid(c:GetOriginalCode(),promptIndex)) end
	e1:SetCategory(CATEGORY_COUNTER+CATEGORY_COIN)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCountLimit(1)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) and f(chkc) end
		if chk==0 then return Duel.IsExistingTarget(f,tp,0,LOCATION_MZONE,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_COUNTER)
		Duel.SelectTarget(tp,f,tp,0,LOCATION_MZONE,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_COIN,nil,0,tp,1)
	end)
	e1:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if Duel.CallCoin(tp) and tc and tc:IsRelateToEffect(e) and tc:IsFaceup() then tc:AddCounter(COUNTER_POISON,1) end
	end)
	c:RegisterEffect(e1)
end

-- ----------------------------------------------------------------------------
-- REVEAL, OPPONENT PICKS AT RANDOM (Elite Four)
-- Shows the cards in g to the opponent, the opponent picks 1 of them at random and it goes to tp's hand, the rest
-- are shuffled into the Deck.
-- ----------------------------------------------------------------------------
function Pokemon.RevealRandomAdd(tp,g)
	Duel.ConfirmCards(1-tp,g)
	local tc=g:RandomSelect(1-tp,1):GetFirst()
	Duel.SendtoHand(tc,nil,REASON_EFFECT)
	Duel.ConfirmCards(1-tp,tc)
	Duel.ShuffleDeck(tp)
end

-- ----------------------------------------------------------------------------
-- "UMI IS ON THE FIELD" (Goldeen, Seaking). Counts the real Umi and Rain Dance (which is also treated as Umi),
-- wherever it is on the field.
-- ----------------------------------------------------------------------------
function Pokemon.IsUmi() return Duel.IsEnvironment(CARD_UMI,PLAYER_ALL,LOCATION_ONFIELD) end

-- ----------------------------------------------------------------------------
-- STANDBY LP GAIN (Chansey, Tangela): "During your Standby Phase: Gain <amount> LP." (mandatory)
-- ----------------------------------------------------------------------------
function Pokemon.AddStandbyRecover(c,amount)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_RECOVER)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_RECOVER,nil,0,tp,amount)
	end)
	e1:SetOperation(function(e,tp) Duel.Recover(tp,amount,REASON_EFFECT) end)
	c:RegisterEffect(e1)
end

-- ----------------------------------------------------------------------------
-- EXCAVATE AND ADD (Staryu, Starmie, Power Plant-style)
-- "Excavate the top <n> cards of your Deck, and if there are any <filter> among them, add 1 to your hand,
--  also shuffle the rest into the Deck."   Call it from an operation: Pokemon.ExcavateAdd(tp, 3, filter)
-- ----------------------------------------------------------------------------
function Pokemon.ExcavateAdd(tp,n,filter)
	if Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)<n then return end
	Duel.ConfirmDecktop(tp,n)
	local g=Duel.GetDecktopGroup(tp,n):Filter(function(tc) return filter(tc) and tc:IsAbleToHand() end,nil)
	if #g>0 then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local sg=g:Select(tp,1,1,nil)
		Duel.DisableShuffleCheck()
		Duel.SendtoHand(sg,nil,REASON_EFFECT)
		Duel.ConfirmCards(1-tp,sg)
	end
	Duel.ShuffleDeck(tp)
end

-- ----------------------------------------------------------------------------
-- RITUAL HELPERS (Jynx, Electabuzz, Magmar)
-- "When you Ritual Summon 1 <attr> monster, you can banish this card from your field or GY as the entire Tribute."
-- From the field it is used like the real "Ritual Raven" (Tributed as the whole Tribute); from the GY it is
-- banished (like "Forbidden Ritual Art" materials).
-- ----------------------------------------------------------------------------
function Pokemon.AddRitualWholeTribute(c,attr)
	Ritual.AddWholeLevelTribute(c,function(rc) return rc:IsAttribute(attr) end)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_GRAVE)
	e1:SetCode(EFFECT_EXTRA_RITUAL_MATERIAL)
	e1:SetCondition(function(e) return e:GetHandler():IsAbleToRemove() end)
	e1:SetValue(function(e,rc) return rc:IsAttribute(attr) end)
	c:RegisterEffect(e1)
end

-- ----------------------------------------------------------------------------
-- DRAWS OUTSIDE THE DRAW PHASE (Tauros)
-- Pokemon.EnableDrawTracker(): remembers, for each player, the last turn they drew outside their Draw Phase.
-- Pokemon.DrewOutsideDrawPhase(p, turnsAgo): did player p draw outside the Draw Phase this turn (0) or last turn (1)?
-- ----------------------------------------------------------------------------
Pokemon.oddDrawTurns={[0]={},[1]={}}
function Pokemon.EnableDrawTracker()
	if Pokemon.drawTrackerOn then return end
	Pokemon.drawTrackerOn=true
	local ge=Effect.GlobalEffect()
	ge:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	ge:SetCode(EVENT_DRAW)
	ge:SetOperation(function(e,tp,eg,ep)
		if Duel.GetCurrentPhase()~=PHASE_DRAW then Pokemon.oddDrawTurns[ep][Duel.GetTurnCount()]=true end
	end)
	Duel.RegisterEffect(ge,0)
end
function Pokemon.DrewOutsideDrawPhase(p,turnsAgo)
	return Pokemon.oddDrawTurns[p][Duel.GetTurnCount()-(turnsAgo or 0)]==true
end

-- ----------------------------------------------------------------------------
-- JYNX / ELECTABUZZ / MAGMAR
-- Pokemon.AddRitualTrio(c, attribute, nextCode):
--  * whole Ritual Tribute for a Ritual monster of that Attribute (Pokemon.AddRitualWholeTribute)
--  * Normal Summoned: you can search nextCode
--  * Tribute Summoned + battle damage: excavate the top card; if it's a Pokemon of that Attribute, apply its lock
--    (WATER: no Spells next turn / LIGHT: skip their next Battle Phase / FIRE: no Traps until the end of your next turn)
-- ----------------------------------------------------------------------------
function Pokemon.AddRitualTrio(c,attr,nextCode)
	Pokemon.AddRitualWholeTribute(c,attr)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(c:GetOriginalCode(),0))
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	local function th(tc) return tc:IsCode(nextCode) and tc:IsAbleToHand() end
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(th,tp,LOCATION_DECK,0,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectMatchingCard(tp,th,tp,LOCATION_DECK,0,1,1,nil)
		if #g>0 then Duel.SendtoHand(g,nil,REASON_EFFECT) Duel.ConfirmCards(1-tp,g) end
	end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_BATTLE_DAMAGE)
	e2:SetCondition(function(e,tp,eg,ep) return ep==1-tp and e:GetHandler():IsSummonType(SUMMON_TYPE_TRIBUTE) end)
	e2:SetOperation(function(e,tp)
		if Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)==0 then return end
		Duel.ConfirmDecktop(tp,1)
		local tc=Duel.GetDecktopGroup(tp,1):GetFirst()
		if tc:IsMonster() and tc:IsSetCard(SET_POKEMON) and tc:IsAttribute(attr) then
			local ef=Effect.CreateEffect(e:GetHandler())
			ef:SetType(EFFECT_TYPE_FIELD)
			ef:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
			ef:SetTargetRange(0,1)
			if attr==ATTRIBUTE_LIGHT then
				ef:SetCode(EFFECT_SKIP_BP)
				ef:SetReset(RESET_PHASE|PHASE_END|RESET_OPPO_TURN)
			else
				local ty=(attr==ATTRIBUTE_WATER) and TYPE_SPELL or TYPE_TRAP
				ef:SetCode(EFFECT_CANNOT_ACTIVATE)
				ef:SetValue(function(x,re) return re:IsHasType(EFFECT_TYPE_ACTIVATE) and re:IsActiveType(ty) end)
				if attr==ATTRIBUTE_WATER then
					-- during their next turn only
					ef:SetCondition(function() return Duel.IsTurnPlayer(1-tp) end)
					ef:SetReset(RESET_PHASE|PHASE_END|RESET_OPPO_TURN)
				else
					-- from now until the end of your next turn
					ef:SetReset(RESET_PHASE|PHASE_END|RESET_SELF_TURN,Duel.IsTurnPlayer(tp) and 2 or 1)
				end
			end
			Duel.RegisterEffect(ef,tp)
		end
		Duel.ShuffleDeck(tp)
	end)
	c:RegisterEffect(e2)
end

-- Menu text for a Counter: Duel.SelectOption(tp,Pokemon.CounterDesc(COUNTER_SPELL)) shows "Spell Counters".
-- Names come from content/counter-names.json (official) and content/custom/counters.json (ours).
function Pokemon.CounterDesc(kind) return 0x7c00000000000000+kind end

-- ----------------------------------------------------------------------------
-- EEVEE EVOLUTIONS (Vaporeon, Jolteon, Flareon)
-- "You can Special Summon this card (from your Deck) by Tributing 1 "Eevee" and discarding 1 "<Stone>".
--  You can Special Summon this card from your hand by Tributing 1 "Eevee" from your hand or field, or by
--  banishing 1 "Eevee" from your GY. You can only Special Summon "<name>" once per turn."
-- HOW TO USE: Pokemon.AddEeveelution(c, CARD_WATER_STONE)
-- ----------------------------------------------------------------------------
function Pokemon.AddEeveelution(c,stoneCode)
	c:SetSPSummonOnce(c:GetOriginalCode())          -- any way of Special Summoning it: once per turn
	Pokemon.AddEvolutionSummon(c,CARD_EEVEE,true)    -- from the hand, like the other evolutions
	local function eevee(mc,tp) return mc:IsFaceup() and mc:IsCode(CARD_EEVEE) and mc:IsReleasable() and Duel.GetMZoneCount(tp,mc)>0 end
	local function stone(sc) return sc:IsCode(stoneCode) and sc:IsDiscardable() end
	local e=Effect.CreateEffect(c)
	e:SetType(EFFECT_TYPE_FIELD)
	e:SetCode(EFFECT_SPSUMMON_PROC)
	e:SetProperty(EFFECT_FLAG_UNCOPYABLE)
	e:SetRange(LOCATION_DECK)                        -- shows up as "Special Summon <name>" from your Deck
	e:SetValue(Pokemon.EVOLUTION)
	e:SetCondition(function(e,c)
		if c==nil then return true end
		local tp=c:GetControler()
		return Duel.IsExistingMatchingCard(eevee,tp,LOCATION_MZONE,0,1,nil,tp)
			and Duel.IsExistingMatchingCard(stone,tp,LOCATION_HAND,0,1,nil)
	end)
	e:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,c)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RELEASE)
		local g1=Duel.SelectMatchingCard(tp,eevee,tp,LOCATION_MZONE,0,1,1,nil,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DISCARD)
		local g2=Duel.SelectMatchingCard(tp,stone,tp,LOCATION_HAND,0,1,1,nil)
		if #g1==0 or #g2==0 then return false end
		g1:Merge(g2)
		g1:KeepAlive()
		e:SetLabelObject(g1)
		return true
	end)
	e:SetOperation(function(e,tp,eg,ep,ev,re,r,rp,c)
		local g=e:GetLabelObject()
		Duel.Release(g:Filter(Card.IsLocation,nil,LOCATION_MZONE),REASON_COST)
		Duel.SendtoGrave(g:Filter(Card.IsLocation,nil,LOCATION_HAND),REASON_COST|REASON_DISCARD)
		g:DeleteGroup()
	end)
	c:RegisterEffect(e)
end

-- ----------------------------------------------------------------------------
-- FOSSIL SUMMONS
-- Pokemon.AddFossilSummon(c, cost, count, mustOnly, fromCode)
--  * "banish": banish <count> cards from your GY that match <cost> (Omanyte, Kabuto, Aerodactyl)
--  * "evolve": Tribute 1 <fromCode> you control, or banish 1 <fromCode> from your GY; once per turn this way
--    (Omastar, Kabutops)
-- Always "Cannot be Normal Summoned/Set" and Special Summoned from the hand. mustOnly = "Must be Special Summoned
-- (this way)" (nothing else can Summon it); otherwise it is "must FIRST be Special Summoned this way".
-- ----------------------------------------------------------------------------
function Pokemon.AddFossilSummon(c,kind,cost,count,mustOnly,fromCode)
	c:EnableUnsummonable()
	c:EnableReviveLimit()
	if mustOnly then
		local e0=Effect.CreateEffect(c)
		e0:SetType(EFFECT_TYPE_SINGLE)
		e0:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
		e0:SetCode(EFFECT_SPSUMMON_CONDITION)
		e0:SetValue(aux.FALSE)
		c:RegisterEffect(e0)
	end
	local function mat(mc,tp,self)
		if mc==self then return false end
		if kind=="banish" then return mc:IsLocation(LOCATION_GRAVE) and cost(mc) and mc:IsAbleToRemoveAsCost() end
		if not mc:IsCode(fromCode) then return false end
		if mc:IsLocation(LOCATION_GRAVE) then return mc:IsAbleToRemoveAsCost() and Duel.GetLocationCount(tp,LOCATION_MZONE)>0 end
		return mc:IsFaceup() and mc:IsReleasable() and Duel.GetMZoneCount(tp,mc)>0
	end
	local where=kind=="banish" and LOCATION_GRAVE or LOCATION_MZONE|LOCATION_GRAVE
	local n=kind=="banish" and count or 1
	local e=Effect.CreateEffect(c)
	e:SetType(EFFECT_TYPE_FIELD)
	e:SetCode(EFFECT_SPSUMMON_PROC)
	e:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_CANNOT_DISABLE)
	e:SetRange(LOCATION_HAND)
	e:SetValue(Pokemon.EVOLUTION)
	if kind=="evolve" then e:SetCountLimit(1,{c:GetOriginalCode(),10},EFFECT_COUNT_CODE_OATH) end
	e:SetCondition(function(e,c)
		if c==nil then return true end
		local tp=c:GetControler()
		if kind=="banish" and Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return false end
		return Duel.IsExistingMatchingCard(mat,tp,where,0,n,nil,tp,c)
	end)
	e:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,c)
		Duel.Hint(HINT_SELECTMSG,tp,kind=="banish" and HINTMSG_REMOVE or HINTMSG_RELEASE)
		local g=Duel.SelectMatchingCard(tp,mat,tp,where,0,n,n,nil,tp,c)
		if #g<n then return false end
		g:KeepAlive()
		e:SetLabelObject(g)
		return true
	end)
	e:SetOperation(function(e,tp,eg,ep,ev,re,r,rp,c)
		local g=e:GetLabelObject()
		Duel.Remove(g:Filter(Card.IsLocation,nil,LOCATION_GRAVE),POS_FACEUP,REASON_COST)
		Duel.Release(g:Filter(Card.IsLocation,nil,LOCATION_MZONE),REASON_COST)
		g:DeleteGroup()
	end)
	c:RegisterEffect(e)
end

-- "Once per turn, while "Rain Dance" is on the field (Quick Effect): You can change this card's battle position."
function Pokemon.AddRainPositionChange(c,promptIndex)
	local e=Effect.CreateEffect(c)
	e:SetDescription(aux.Stringid(c:GetOriginalCode(),promptIndex))
	e:SetCategory(CATEGORY_POSITION)
	e:SetType(EFFECT_TYPE_QUICK_O)
	e:SetCode(EVENT_FREE_CHAIN)
	e:SetRange(LOCATION_MZONE)
	e:SetCountLimit(1)
	e:SetHintTiming(TIMING_ATTACK|TIMING_BATTLE_START,TIMING_ATTACK|TIMING_BATTLE_START|TIMING_END_PHASE)
	e:SetCondition(function() return Pokemon.IsOnField(CARD_RAIN_DANCE) end)
	e:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return e:GetHandler():IsCanChangePosition() end
		Duel.SetOperationInfo(0,CATEGORY_POSITION,e:GetHandler(),1,0,0)
	end)
	e:SetOperation(function(e)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) and c:IsFaceup() then Duel.ChangePosition(c,POS_FACEUP_DEFENSE,0,POS_FACEUP_ATTACK,0) end
	end)
	c:RegisterEffect(e)
end
