-- Fearow (Gemini)
-- Evolution Summon from "Spearow" (hard once per turn).
-- Gemini: a Normal Monster until it is Normal Summoned again while on the field; then it gains:
-- * Once per turn: You can look at the top card of your opponent's Deck, then shuffle their Deck.
--   If it was a Normal Spell, this card gains that Spell's effect until the end of this turn (use it once).
-- PATTERN: Gemini = Gemini.AddProcedure(c) + Gemini.EffectStatusCondition on its effects.
-- The Spell copy works like Destiny HERO - Diamond Dude.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000029)   -- from Spearow
	Gemini.AddProcedure(c)

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(Gemini.EffectStatusCondition)   -- only after its second Normal Summon
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetFieldGroupCount(tp,0,LOCATION_DECK)>0 end
	end)
	e1:SetOperation(s.lookop)
	c:RegisterEffect(e1)
end
s.listed_names={1900000029}

function s.lookop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local tc=Duel.GetDecktopGroup(1-tp,1):GetFirst()
	if not tc then return end
	Duel.ConfirmCards(tp,tc)                  -- only you see it
	local copy=tc:IsNormalSpell() and tc:GetActivateEffect()
	Duel.ShuffleDeck(1-tp)
	if not (copy and c:IsRelateToEffect(e) and c:IsFaceup()) then return end
	-- Gain that Spell's effect until the end of the turn
	local ge=Effect.CreateEffect(c)
	ge:SetDescription(aux.Stringid(id,1))     -- Prompt 2
	ge:SetCategory(copy:GetCategory())
	ge:SetType(EFFECT_TYPE_IGNITION)
	ge:SetRange(LOCATION_MZONE)
	ge:SetProperty(EFFECT_FLAG_CLIENT_HINT)
	ge:SetCountLimit(1)
	ge:SetReset(RESETS_STANDARD_PHASE_END)
	ge:SetLabelObject(tc)                      -- remember which Spell was seen
	ge:SetTarget(s.copytg)
	ge:SetOperation(s.copyop)
	c:RegisterEffect(ge)
end
-- Run the copied Spell's own target and operation functions.
function s.copytg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	local ae=e:GetLabelObject():GetActivateEffect()
	local ftg=ae:GetTarget()
	if chkc then return ftg and ftg(e,tp,eg,ep,ev,re,r,rp,chk,chkc) end
	if chk==0 then return not ftg or ftg(e,tp,eg,ep,ev,re,r,rp,0) end
	e:SetProperty(ae:IsHasProperty(EFFECT_FLAG_CARD_TARGET) and EFFECT_FLAG_CARD_TARGET or 0)
	if ftg then ftg(e,tp,eg,ep,ev,re,r,rp,1) end
end
function s.copyop(e,tp,eg,ep,ev,re,r,rp)
	local fop=e:GetLabelObject():GetActivateEffect():GetOperation()
	if fop then fop(e,tp,eg,ep,ev,re,r,rp) end
end
