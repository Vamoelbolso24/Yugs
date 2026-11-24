-- Gyarados
-- Cannot be Normal Summoned/Set. Must be Special Summoned (from your hand) by Tributing 1 "Magikarp" you control.
-- This card's Special Summon cannot be negated.
-- When this card is Special Summoned: Halve the ATK of all monsters your opponent controls, also negate their effects
-- until the end of this turn.
-- If this card is attacked by a Thunder Pokemon monster, before damage calculation: Destroy this card.
-- When a Normal Trap card is activated (Quick Effect): You can discard 1 card; negate the activation, and if you do,
-- destroy it.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddNomiSummon(c,1900000198)       -- Tribute 1 Magikarp you control
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_SINGLE)
	e0:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e0:SetCode(EFFECT_CANNOT_DISABLE_SPSUMMON)  -- its Summon can't be negated
	c:RegisterEffect(e0)
	-- On Special Summon: halve ATK and negate (mandatory)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_ATKCHANGE+CATEGORY_DISABLE)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetOperation(function(e,tp)
		for tc in Duel.GetMatchingGroup(Card.IsFaceup,tp,0,LOCATION_MZONE,nil):Iter() do
			local ef=Effect.CreateEffect(e:GetHandler())
			ef:SetType(EFFECT_TYPE_SINGLE)
			ef:SetCode(EFFECT_SET_ATTACK_FINAL)
			ef:SetValue(math.ceil(tc:GetAttack()/2))
			ef:SetReset(RESET_EVENT|RESETS_STANDARD)
			tc:RegisterEffect(ef)
			for _,code in ipairs({EFFECT_DISABLE,EFFECT_DISABLE_EFFECT}) do
				local ed=Effect.CreateEffect(e:GetHandler())
				ed:SetType(EFFECT_TYPE_SINGLE)
				ed:SetCode(code)
				ed:SetReset(RESETS_STANDARD_PHASE_END)
				tc:RegisterEffect(ed)
			end
		end
	end)
	c:RegisterEffect(e1)
	-- Attacked by a Thunder Pokemon: destroyed before damage calculation
	local e2=Effect.CreateEffect(c)
	e2:SetCategory(CATEGORY_DESTROY)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_BATTLE_CONFIRM)
	e2:SetCondition(function(e)
		local a=Duel.GetAttacker()
		return Duel.GetAttackTarget()==e:GetHandler() and a and a:IsRace(RACE_THUNDER) and a:IsSetCard(SET_POKEMON)
	end)
	e2:SetOperation(function(e)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) then Duel.Destroy(c,REASON_EFFECT) end
	end)
	c:RegisterEffect(e2)
	-- Negate a Normal Trap
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_NEGATE+CATEGORY_DESTROY)
	e3:SetType(EFFECT_TYPE_QUICK_O)
	e3:SetCode(EVENT_CHAINING)
	e3:SetRange(LOCATION_MZONE)
	e3:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e3:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		return re:IsHasType(EFFECT_TYPE_ACTIVATE) and re:GetHandler():IsNormalTrap() and Duel.IsChainNegatable(ev)
	end)
	e3:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,nil) end
		Duel.DiscardHand(tp,Card.IsDiscardable,1,1,REASON_COST|REASON_DISCARD)
	end)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_NEGATE,eg,1,0,0)
		if re:GetHandler():IsRelateToEffect(re) then Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,1,0,0) end
	end)
	e3:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		if Duel.NegateActivation(ev) and re:GetHandler():IsRelateToEffect(re) then Duel.Destroy(eg,REASON_EFFECT) end
	end)
	c:RegisterEffect(e3)
end
s.listed_names={1900000198}
