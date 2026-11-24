-- Busy Signal (Normal Trap)
-- "When an opponent's monster declares an attack: Negate the attack,
--  then your opponent takes 500 damage."
--
-- HOW TO REUSE THIS: this is the classic "Negate Attack" shape. For other
-- "When an opponent's monster declares an attack:" traps, keep the same
-- SetCode/SetCondition and only change s.activate.
-- Similar real cards: Negate Attack (14315573), Magic Cylinder (62279055).

local s,id=GetID()

function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)       -- ACTIVATE = this is how a Spell/Trap card itself is activated
	e1:SetCode(EVENT_ATTACK_ANNOUNCE)      -- WHEN: a monster declares an attack
	e1:SetCondition(s.condition)           -- extra check: only the opponent's attacks
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end

-- Condition: the attacking player (Duel.GetTurnPlayer) must be the opponent (1-tp).
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.GetTurnPlayer()~=tp
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,500) -- announce: 500 damage to the opponent
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
	if Duel.NegateAttack() then                -- returns true if the attack was really negated
		Duel.Damage(1-tp,500,REASON_EFFECT)    -- 1-tp = the opponent of this card's controller
	end
end
