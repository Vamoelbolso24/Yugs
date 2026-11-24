-- Alakazam
-- Cannot be Normal Summoned/Set. Must first be Special Summoned (from your hand) by Tributing 1 "Kadabra" you control.
-- If Summoned this way: You can destroy all face-up Spells/Traps your opponent controls.
-- Cannot be destroyed by your opponent's Spell effects, also your opponent cannot target this card with Spell effects.
-- Control of this card cannot change.
-- If this card inflicts battle damage to your opponent: Draw 1 card.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddNomiSummon(c,1900000105)       -- Tribute 1 Kadabra you control
	Pokemon.AddNoControlChange(c)

	-- On Summon: destroy face-up Spells/Traps
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetCondition(function(e) return Pokemon.IsNomiSummoned(e:GetHandler()) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local g=Duel.GetMatchingGroup(s.stfilter,tp,0,LOCATION_ONFIELD,nil)
		if chk==0 then return #g>0 end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,#g,0,0)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Destroy(Duel.GetMatchingGroup(s.stfilter,tp,0,LOCATION_ONFIELD,nil),REASON_EFFECT)
	end)
	c:RegisterEffect(e1)
	-- Opponent's Spells can't destroy or target it
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
	e2:SetValue(s.oppspell)
	c:RegisterEffect(e2)
	local e3=e2:Clone()
	e3:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	c:RegisterEffect(e3)
	-- Battle damage -> draw 1
	local e4=Effect.CreateEffect(c)
	e4:SetCategory(CATEGORY_DRAW)
	e4:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e4:SetCode(EVENT_BATTLE_DAMAGE)
	e4:SetCondition(function(e,tp,eg,ep) return ep==1-tp end)
	e4:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
	end)
	e4:SetOperation(function(e,tp) Duel.Draw(tp,1,REASON_EFFECT) end)
	c:RegisterEffect(e4)
end
s.listed_names={1900000105}
function s.stfilter(c) return c:IsFaceup() and c:IsSpellTrap() end
-- re = the effect trying to destroy/target it
function s.oppspell(e,re,rp)
	return re:IsActiveType(TYPE_SPELL) and re:GetOwnerPlayer()~=e:GetHandlerPlayer()
end
