-- Wartortle
-- Evolution Summon from "Squirtle".
-- At the end of the Battle Phase, if this card attacked: You can change it to Defense Position.
-- If this card destroys a monster by battle: You can toss a coin and call it; if right, draw 1 card.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000008)   -- EVOLUTION SUMMON from Squirtle

	-- PATTERN: "At the end of the Battle Phase, if this card attacked" (like Goblin Attack Force, but optional).
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))      -- Prompt 1
	e1:SetCategory(CATEGORY_POSITION)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_PHASE+PHASE_BATTLE)       -- end of the Battle Phase
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1)
	e1:SetCondition(s.poscon)
	e1:SetOperation(s.posop)
	c:RegisterEffect(e1)

	-- PATTERN: "If this card destroys a monster by battle" = EVENT_BATTLE_DESTROYING + aux.bdcon.
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))      -- Prompt 2
	e2:SetCategory(CATEGORY_COIN+CATEGORY_DRAW)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e2:SetCode(EVENT_BATTLE_DESTROYING)
	e2:SetCondition(aux.bdcon)                 -- it destroyed it by battle and is still on the field
	e2:SetTarget(s.drtg)
	e2:SetOperation(s.drop)
	c:RegisterEffect(e2)
end
s.listed_names={1900000008}

function s.poscon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	return c:GetAttackedCount()>0 and c:IsAttackPos() and c:IsCanChangePosition()
end
function s.posop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if c:IsRelateToEffect(e) and c:IsFaceup() and c:IsAttackPos() then
		Duel.ChangePosition(c,POS_FACEUP_DEFENSE)
	end
end
function s.drtg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsPlayerCanDraw(tp,1) end
	Duel.SetOperationInfo(0,CATEGORY_COIN,nil,0,tp,1)
end
function s.drop(e,tp,eg,ep,ev,re,r,rp)
	if Duel.CallCoin(tp) then
		Duel.Draw(tp,1,REASON_EFFECT)
	end
end
