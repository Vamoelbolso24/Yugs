-- Muk
-- Evolution Summon from "Grimer" (hard once per turn).
-- Your opponent cannot target Equip Spells you control with card effects, also they cannot be destroyed by your
-- opponent's card effects.
-- Once per turn: You can place 1 Poison Counter on up to 2 monsters on the field.
-- Once per turn, when a monster your opponent controls declares an attack: You can send the top card of your Deck
-- to the GY; negate the attack.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000145)   -- from Grimer
	Pokemon.EnablePoisonRule()
	-- Protect your Equip Spells
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	e1:SetRange(LOCATION_MZONE)
	e1:SetTargetRange(LOCATION_SZONE,0)
	e1:SetTarget(function(e,tc) return tc:IsFaceup() and tc:IsType(TYPE_EQUIP) and tc:IsSpell() end)
	e1:SetValue(aux.tgoval)
	c:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
	e2:SetValue(aux.indoval)                   -- not by your opponent's effects
	c:RegisterEffect(e2)
	-- Poison up to 2 monsters (any side, chosen when it resolves)
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_COUNTER)
	e3:SetType(EFFECT_TYPE_IGNITION)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCountLimit(1)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.pfilter,tp,LOCATION_MZONE,LOCATION_MZONE,1,nil) end
	end)
	e3:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_COUNTER)
		local g=Duel.SelectMatchingCard(tp,s.pfilter,tp,LOCATION_MZONE,LOCATION_MZONE,1,2,nil)
		for tc in g:Iter() do tc:AddCounter(COUNTER_POISON,1) end
	end)
	c:RegisterEffect(e3)
	-- Negate an attack
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,1))
	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e4:SetCode(EVENT_ATTACK_ANNOUNCE)
	e4:SetRange(LOCATION_MZONE)
	e4:SetCountLimit(1)
	e4:SetCondition(function(e,tp) return Duel.GetAttacker():IsControler(1-tp) end)
	e4:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsPlayerCanDiscardDeckAsCost(tp,1) end
		Duel.DiscardDeck(tp,1,REASON_COST)
	end)
	e4:SetOperation(function() Duel.NegateAttack() end)
	c:RegisterEffect(e4)
end
s.listed_names={1900000145}
function s.pfilter(c) return c:IsFaceup() and c:IsCanAddCounter(COUNTER_POISON,1) end
