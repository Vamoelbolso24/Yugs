-- Gym Leader - Misty (Continuous Spell)
-- You can only control 1 "Gym Leader" card.
-- Aqua, Sea Serpent, and Fish Pokemon monsters you control gain 400 ATK during your Battle Phase.
-- If an Aqua, Sea Serpent, or Fish Pokemon monster you control destroys a monster your opponent controls by
-- battle: You can discard 1 WATER monster; draw 1 card.
local s,id=GetID()
local RACES=RACE_AQUA|RACE_SEASERPENT|RACE_FISH
function s.initial_effect(c)
	Pokemon.AddGymLeader(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetRange(LOCATION_SZONE)
	e1:SetTargetRange(LOCATION_MZONE,0)
	e1:SetCondition(function(e) return Duel.IsTurnPlayer(e:GetHandlerPlayer()) and Duel.IsBattlePhase() end)
	e1:SetTarget(function(e,tc) return s.waterpoke(tc) end)
	e1:SetValue(400)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_DRAW)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e2:SetCode(EVENT_BATTLE_DESTROYING)
	e2:SetRange(LOCATION_SZONE)
	e2:SetProperty(EFFECT_FLAG_DELAY)
	e2:SetCondition(function(e,tp,eg)
		local tc=eg:GetFirst()
		return tc:IsControler(tp) and s.waterpoke(tc) and tc:GetBattleTarget() and tc:GetBattleTarget():IsPreviousControler(1-tp)
	end)
	e2:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.discard,tp,LOCATION_HAND,0,1,nil) end
		Duel.DiscardHand(tp,s.discard,1,1,REASON_COST|REASON_DISCARD)
	end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsPlayerCanDraw(tp,1) end
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
	end)
	e2:SetOperation(function(e,tp)
		if e:GetHandler():IsRelateToEffect(e) then Duel.Draw(tp,1,REASON_EFFECT) end
	end)
	c:RegisterEffect(e2)
end
function s.waterpoke(c) return c:IsFaceup() and c:IsSetCard(SET_POKEMON) and c:IsRace(RACES) end
function s.discard(c) return c:IsMonster() and c:IsAttribute(ATTRIBUTE_WATER) and c:IsDiscardable() end
