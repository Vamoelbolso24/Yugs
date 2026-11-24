-- Gym Leader - Giovanni (Continuous Spell)
-- (This card is always treated as a "Team Rocket" card.)
-- Activate only if you control 2 or more Level 7 or higher EARTH Pokemon monsters.
-- You can only control 1 "Gym Leader" card.
-- Once per turn (Quick Effect): When your opponent would Special Summon a monster: You can banish 2 EARTH
-- Pokemon monsters from your GY; negate the Summon, and if you do, destroy it.
-- NOTE: like Solemn Strike, this can only stop Summons that don't use a Chain (Evolution Summons, Golbat...),
-- not monsters Special Summoned by a card effect.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddGymLeader(c,function(e,tp)
		return Duel.IsExistingMatchingCard(s.bigearth,tp,LOCATION_MZONE,0,2,nil)
	end)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_DISABLE_SUMMON+CATEGORY_DESTROY)
	e2:SetType(EFFECT_TYPE_QUICK_O)
	e2:SetCode(EVENT_SPSUMMON)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCountLimit(1)
	e2:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		return Duel.GetCurrentChain()==0 and ep==1-tp   -- ep = the player Summoning
	end)
	e2:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.costfilter,tp,LOCATION_GRAVE,0,2,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
		local g=Duel.SelectMatchingCard(tp,s.costfilter,tp,LOCATION_GRAVE,0,2,2,nil)
		Duel.Remove(g,POS_FACEUP,REASON_COST)
	end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DISABLE_SUMMON,eg,#eg,0,0)
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,#eg,0,0)
	end)
	e2:SetOperation(function(e,tp,eg)
		Duel.NegateSummon(eg)
		Duel.Destroy(eg,REASON_EFFECT)
	end)
	c:RegisterEffect(e2)
end
function s.bigearth(c) return c:IsFaceup() and c:IsSetCard(SET_POKEMON) and c:IsAttribute(ATTRIBUTE_EARTH) and c:IsLevelAbove(7) end
function s.costfilter(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and c:IsAttribute(ATTRIBUTE_EARTH) and c:IsAbleToRemoveAsCost() end
